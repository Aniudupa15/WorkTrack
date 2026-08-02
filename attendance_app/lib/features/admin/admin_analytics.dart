import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:attendance_app/core/di/injection.dart';
import 'package:attendance_app/core/theme/app_colors.dart';
import 'package:attendance_app/core/theme/app_spacing.dart';
import 'package:attendance_app/core/widgets/app_loader.dart';
import 'package:attendance_app/core/widgets/empty_state.dart';
import 'package:attendance_app/data/datasources/analytics_service.dart';
import 'package:attendance_app/data/datasources/report_service.dart';
import 'package:attendance_app/data/models/attendance_model.dart';
import 'package:attendance_app/domain/repositories/attendance_repository.dart';
import 'package:attendance_app/features/shared/user_provider.dart';

class AdminAnalytics extends StatefulWidget {
  const AdminAnalytics({super.key});

  @override
  State<AdminAnalytics> createState() => _AdminAnalyticsState();
}

class _AdminAnalyticsState extends State<AdminAnalytics> {
  final _attendance = sl<AttendanceRepository>();
  DateTime _selectedMonth = DateTime.now();
  List<AttendanceModel> _records = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final companyId =
        Provider.of<UserProvider>(context, listen: false).company?.id ?? '';
    final ym = DateFormat('yyyy-MM').format(_selectedMonth);
    _records = await _attendance.getAttendanceForMonth(companyId, ym);
    if (mounted) setState(() => _loading = false);
  }

  void _changeMonth(int delta) {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + delta,
      );
    });
    _loadData();
  }

  Future<void> _exportCsv() async {
    if (_records.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nothing to export for this month.')),
      );
      return;
    }
    final company = Provider.of<UserProvider>(context, listen: false).company;
    try {
      await sl<ReportService>().shareAttendanceCsv(
        companyName: company?.name ?? 'Company',
        month: _selectedMonth,
        records: _records,
      );
      await sl<AnalyticsService>().logReportExported();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not export the report.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final present = _records.where((r) => r.status == 'present').length;
    final late = _records.where((r) => r.status == 'late').length;
    final absent = _records.where((r) => r.status == 'absent').length;
    final halfDay = _records.where((r) => r.status == 'half_day').length;
    final total = _records.length;

    final segments = <_Segment>[
      _Segment('Present', present, colors.success),
      _Segment('Late', late, colors.warning),
      _Segment('Absent', absent, colors.danger),
      _Segment('Half Day', halfDay, colors.info),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share_rounded),
            tooltip: 'Export CSV',
            onPressed: _loading ? null : _exportCsv,
          ),
        ],
      ),
      body: _loading
          ? const AppLoader()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: () => _changeMonth(-1),
                        icon: const Icon(Icons.chevron_left),
                      ),
                      Text(
                        DateFormat('MMMM yyyy').format(_selectedMonth),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      IconButton(
                        onPressed: () => _changeMonth(1),
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Row(
                    children: [
                      for (final s in segments) ...[
                        _statCard(s),
                        if (s != segments.last)
                          const SizedBox(width: AppSpacing.sm),
                      ],
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  if (total > 0) ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Attendance Distribution',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    SizedBox(
                      height: 200,
                      child: PieChart(
                        PieChartData(
                          sectionsSpace: 2,
                          centerSpaceRadius: 40,
                          sections: [
                            for (final s in segments)
                              if (s.count > 0)
                                PieChartSectionData(
                                  value: s.count.toDouble(),
                                  title: '${s.count}',
                                  color: s.color,
                                  radius: 50,
                                  titleStyle: TextStyle(
                                    color: colors.onBrand,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Wrap(
                      spacing: AppSpacing.lg,
                      runSpacing: AppSpacing.sm,
                      children: [for (final s in segments) _legend(s)],
                    ),
                  ] else
                    const EmptyState(
                      icon: Icons.bar_chart_rounded,
                      title: 'No data for this month',
                    ),
                ],
              ),
            ),
    );
  }

  Widget _statCard(_Segment s) {
    final colors = context.colors;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: s.color.withValues(alpha: 0.4)),
        ),
        child: Column(
          children: [
            Text(
              '${s.count}',
              style: TextStyle(
                color: s.color,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              s.label,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _legend(_Segment s) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: s.color, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(s.label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _Segment {
  const _Segment(this.label, this.count, this.color);

  final String label;
  final int count;
  final Color color;
}
