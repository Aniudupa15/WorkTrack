import 'package:flutter/material.dart';

import 'package:attendance_app/core/billing/entitlements.dart';
import 'package:attendance_app/features/admin/payroll_export_sheet.dart';
import 'package:attendance_app/features/billing/paywall.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:attendance_app/core/di/injection.dart';
import 'package:attendance_app/core/theme/app_colors.dart';
import 'package:attendance_app/core/theme/app_spacing.dart';
import 'package:attendance_app/core/widgets/app_card.dart';
import 'package:attendance_app/core/widgets/app_loader.dart';
import 'package:attendance_app/core/widgets/app_page.dart';
import 'package:attendance_app/core/utils/attendance_clock.dart';
import 'package:attendance_app/core/widgets/entity_tile.dart';
import 'package:attendance_app/core/widgets/status_badge.dart';
import 'package:attendance_app/data/models/location_model.dart';
import 'package:attendance_app/domain/repositories/location_repository.dart';
import 'package:attendance_app/data/datasources/analytics_service.dart';
import 'package:attendance_app/data/datasources/report_service.dart';
import 'package:attendance_app/data/models/attendance_model.dart';
import 'package:attendance_app/domain/repositories/attendance_repository.dart';
import 'package:attendance_app/features/shared/leave_balance.dart';
import 'package:attendance_app/features/shared/user_provider.dart';

class AdminAnalytics extends StatefulWidget {
  const AdminAnalytics({super.key});

  @override
  State<AdminAnalytics> createState() => _AdminAnalyticsState();
}

class _AdminAnalyticsState extends State<AdminAnalytics> {
  final _attendance = sl<AttendanceRepository>();
  DateTime _selectedMonth = AttendanceClock.now();
  List<AttendanceModel> _records = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final company = Provider.of<UserProvider>(context, listen: false).company;
    final ym = DateFormat('yyyy-MM').format(_selectedMonth);
    _records = await _attendance.getAttendanceForMonth(
      company?.id ?? '',
      ym,
      since: Entitlements.of(company).historySince,
    );
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _exportCsv() async {
    final ent = Entitlements.of(
      Provider.of<UserProvider>(context, listen: false).company,
    );
    if (!ent.hasPro) {
      return showPaywall(context, PaywallReason.export);
    }
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

  Future<void> _pickMonth() async {
    final now = AttendanceClock.now();
    final months = [
      for (var i = 0; i < 12; i++) DateTime(now.year, now.month - i),
    ];
    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final m in months)
              ListTile(
                title: Text(DateFormat('MMMM yyyy').format(m)),
                trailing:
                    m.year == _selectedMonth.year &&
                        m.month == _selectedMonth.month
                    ? const Icon(Icons.check)
                    : null,
                onTap: () => Navigator.pop(sheet, m),
              ),
          ],
        ),
      ),
    );
    if (picked == null) return;
    setState(() => _selectedMonth = picked);
    _loadData();
  }

  Future<void> _exportBySite() async {
    final prov = Provider.of<UserProvider>(context, listen: false);
    if (!Entitlements.of(prov.company).hasPro) {
      return showPaywall(context, PaywallReason.export);
    }
    final sites = await sl<LocationRepository>().getLocations(
      prov.company?.id ?? '',
    );
    if (!mounted) return;
    final site = await showModalBottomSheet<LocationModel>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final s in sites)
              ListTile(
                title: Text(s.name),
                subtitle: Text(
                  '${_records.where((r) => r.locationId == s.id).length} '
                  'punches',
                ),
                onTap: () => Navigator.pop(sheet, s),
              ),
          ],
        ),
      ),
    );
    if (site == null) return;
    final records = _records.where((r) => r.locationId == site.id).toList();
    if (records.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No punches at ${site.name} this month.')),
      );
      return;
    }
    await sl<ReportService>().shareAttendanceCsv(
      companyName: prov.company?.name ?? 'Company',
      month: _selectedMonth,
      records: records,
      scope: site.name,
    );
  }

  void _payroll() {
    final company = Provider.of<UserProvider>(context, listen: false).company;
    if (!Entitlements.of(company).hasBusiness) {
      showPaywall(context, PaywallReason.payroll);
      return;
    }
    showPayrollExport(context, month: _selectedMonth, records: _records);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final company = Provider.of<UserProvider>(context).company;
    final ent = Entitlements.of(company);

    // Expected = active people × working days so far this month.
    final now = AttendanceClock.now();
    final workingDays = company?.workingDays ?? const [1, 2, 3, 4, 5, 6];
    final lastDay =
        _selectedMonth.year == now.year && _selectedMonth.month == now.month
        ? now.day
        : DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0).day;
    final days =
        [
              for (var d = 1; d <= lastDay; d++)
                DateTime(_selectedMonth.year, _selectedMonth.month, d),
            ]
            .where(
              (d) =>
                  workingDays.contains(d.weekday) &&
                  holidayOn(company, DateFormat('yyyy-MM-dd').format(d)) ==
                      null,
            )
            .toList();
    final people = company?.activeEmployees ?? 0;
    final punched = _records.where((r) => r.checkIn != null).toList();
    final late = punched.where((r) => r.isLate).length;
    final expected = people * days.length;
    final durations = [
      for (final r in _records)
        if (r.workDuration != null) r.workDuration!.inMinutes,
    ];
    String pct(num v) => '${v.round()}%';
    final attendance = expected == 0
        ? '—'
        : pct((punched.length / expected * 100).clamp(0, 100));
    final lateRate = punched.isEmpty ? '—' : pct(late / punched.length * 100);
    final avgDay = durations.isEmpty
        ? '—'
        : '${(durations.reduce((a, b) => a + b) / durations.length / 60).toStringAsFixed(1)}h';

    // The last 12 working days of the month, oldest first.
    final barDays = days.length > 12 ? days.sublist(days.length - 12) : days;
    final fmt = DateFormat('yyyy-MM-dd');
    final bars = [
      for (final d in barDays)
        (
          day: d,
          onTime: punched
              .where((r) => r.date == fmt.format(d) && !r.isLate)
              .length,
          late: punched
              .where((r) => r.date == fmt.format(d) && r.isLate)
              .length,
        ),
    ];
    final peak = [
      people,
      for (final b in bars) b.onTime + b.late,
    ].fold<int>(1, (a, b) => b > a ? b : a);

    Widget stat(String label, String value) => Expanded(
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        radius: AppRadius.md,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(color: colors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );

    Widget dot(Color c, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: c, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );

    const lateColor = Color(0xFFFBBF24);

    return Scaffold(
      appBar: TabHeader(
        title: 'Reports',
        actions: [
          ActionChip(
            onPressed: _pickMonth,
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(DateFormat('MMMM').format(_selectedMonth)),
                Icon(
                  Icons.expand_more_rounded,
                  size: 18,
                  color: colors.textTertiary,
                ),
              ],
            ),
          ),
        ],
      ),
      body: _loading
          ? const AppLoader()
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.xxl,
              ),
              children: [
                Row(
                  children: [
                    stat('Attendance', attendance),
                    const SizedBox(width: AppSpacing.sm),
                    stat('Late rate', lateRate),
                    const SizedBox(width: AppSpacing.sm),
                    stat('Avg day', avgDay),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Daily attendance',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          dot(colors.brand, 'On time'),
                          const SizedBox(width: 10),
                          dot(lateColor, 'Late'),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      if (punched.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Text(
                            'No punches this month yet.',
                            style: TextStyle(color: colors.textTertiary),
                          ),
                        )
                      else
                        Semantics(
                          label:
                              'On-time and late check-ins for the last '
                              '${bars.length} working days',
                          child: SizedBox(
                            height: 140,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                for (final b in bars)
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 3,
                                      ),
                                      child: Tooltip(
                                        message:
                                            '${DateFormat('d MMM').format(b.day)}: '
                                            '${b.onTime} on time, ${b.late} late',
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          mainAxisAlignment:
                                              MainAxisAlignment.end,
                                          children: [
                                            Container(
                                              width: 22,
                                              height: 120 * b.late / peak,
                                              decoration: const BoxDecoration(
                                                color: lateColor,
                                                borderRadius:
                                                    BorderRadius.vertical(
                                                      top: Radius.circular(4),
                                                    ),
                                              ),
                                            ),
                                            Container(
                                              width: 22,
                                              height: 120 * b.onTime / peak,
                                              decoration: BoxDecoration(
                                                color: colors.brand,
                                                borderRadius:
                                                    BorderRadius.vertical(
                                                      top: Radius.circular(
                                                        b.late == 0 ? 4 : 0,
                                                      ),
                                                    ),
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '${b.day.day}',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: colors.textTertiary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 8),
                  child: Text(
                    'DOWNLOAD',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.6,
                      color: colors.textTertiary,
                    ),
                  ),
                ),
                AppGroup(
                  children: [
                    EntityTile(
                      inGroup: true,
                      leading: const IconChip(icon: Icons.description_outlined),
                      title: 'Monthly muster roll',
                      subtitle: 'CSV · every person, every day',
                      trailing: Icon(
                        ent.hasPro
                            ? Icons.download_rounded
                            : Icons.lock_outline_rounded,
                        color: colors.textTertiary,
                      ),
                      onTap: _exportCsv,
                    ),
                    EntityTile(
                      inGroup: true,
                      leading: const IconChip(icon: Icons.description_outlined),
                      title: 'By location',
                      subtitle: 'CSV · one site at a time',
                      trailing: Icon(
                        ent.hasPro
                            ? Icons.download_rounded
                            : Icons.lock_outline_rounded,
                        color: colors.textTertiary,
                      ),
                      onTap: _exportBySite,
                    ),
                    EntityTile(
                      inGroup: true,
                      leading: IconChip(
                        icon: ent.hasBusiness
                            ? Icons.payments_outlined
                            : Icons.lock_outline_rounded,
                        color: ent.hasBusiness ? null : colors.textSecondary,
                        background: ent.hasBusiness
                            ? null
                            : colors.surfaceMuted,
                      ),
                      title: 'Payroll export',
                      subtitle: 'Tally, Zoho Payroll, Keka',
                      trailing: ent.hasBusiness
                          ? Icon(
                              Icons.download_rounded,
                              color: colors.textTertiary,
                            )
                          : const StatusBadge(
                              status: 'brand',
                              label: 'Business',
                              dot: false,
                            ),
                      onTap: _payroll,
                    ),
                  ],
                ),
                if (!ent.hasPro)
                  Padding(
                    padding: const EdgeInsets.only(top: 8, left: 4),
                    child: Text(
                      'Downloads are on Pro and Business.',
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.textTertiary,
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
