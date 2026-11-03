import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:attendance_app/core/di/injection.dart';
import 'package:attendance_app/core/theme/app_colors.dart';
import 'package:attendance_app/core/theme/app_spacing.dart';
import 'package:attendance_app/core/utils/attendance_clock.dart';
import 'package:attendance_app/core/widgets/app_card.dart';
import 'package:attendance_app/core/widgets/app_loader.dart';
import 'package:attendance_app/core/widgets/app_page.dart';
import 'package:attendance_app/core/widgets/entity_tile.dart';
import 'package:attendance_app/core/widgets/section_header.dart';
import 'package:attendance_app/core/widgets/status_badge.dart';
import 'package:attendance_app/data/models/attendance_model.dart';
import 'package:attendance_app/domain/repositories/attendance_repository.dart';
import 'package:attendance_app/features/shared/user_provider.dart';

/// The employee's attendance: a month calendar coloured by status, a legend
/// with counts, and the most recent days.
class MyAttendanceScreen extends StatefulWidget {
  const MyAttendanceScreen({super.key});

  @override
  State<MyAttendanceScreen> createState() => _MyAttendanceScreenState();
}

class _MyAttendanceScreenState extends State<MyAttendanceScreen> {
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    final now = AttendanceClock.now();
    _month = DateTime(now.year, now.month);
  }

  void _shift(int delta) =>
      setState(() => _month = DateTime(_month.year, _month.month + delta));

  @override
  Widget build(BuildContext context) {
    final prov = Provider.of<UserProvider>(context);
    final companyId = prov.company?.id ?? '';
    final uid = prov.user?.id ?? '';
    final canPop = Navigator.of(context).canPop();

    return Scaffold(
      appBar: canPop
          ? AppBar(title: const Text('Attendance'))
          : const TabHeader(title: 'Attendance'),
      body: StreamBuilder<List<AttendanceModel>>(
        stream: sl<AttendanceRepository>().watchEmployeeHistory(companyId, uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppLoader();
          }
          final logs = snapshot.data ?? const <AttendanceModel>[];
          final monthKey = DateFormat('yyyy-MM').format(_month);
          final byDate = {
            for (final l in logs)
              if (l.date.startsWith(monthKey)) l.date: l,
          };
          final now = AttendanceClock.now();
          final isCurrentMonth =
              _month.year == now.year && _month.month == now.month;

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.xs,
              AppSpacing.lg,
              AppSpacing.xxl,
            ),
            children: [
              AppCard(
                child: Column(
                  children: [
                    Row(
                      children: [
                        IconButton(
                          tooltip: 'Previous month',
                          onPressed: () => _shift(-1),
                          icon: const Icon(Icons.chevron_left_rounded),
                        ),
                        Expanded(
                          child: Text(
                            DateFormat('MMMM yyyy').format(_month),
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Next month',
                          onPressed: isCurrentMonth ? null : () => _shift(1),
                          icon: const Icon(Icons.chevron_right_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _MonthGrid(
                      month: _month,
                      byDate: byDate,
                      today: AttendanceClock.today(),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _Legend(records: byDate.values.toList()),
                  ],
                ),
              ),
              const SectionHeader(title: 'Recent days'),
              const SizedBox(height: AppSpacing.sm),
              if (logs.isEmpty)
                const AppCard(child: Text('Your punches will appear here.'))
              else
                AppGroup(
                  children: [
                    for (final log in logs.take(10)) _DayRow(log: log),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.byDate,
    required this.today,
  });

  final DateTime month;
  final Map<String, AttendanceModel> byDate;
  final String today;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leadingBlanks = DateTime(month.year, month.month).weekday - 1;
    final fmt = DateFormat('yyyy-MM-dd');

    final cells = <Widget>[
      for (final d in const ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
        Center(child: Text(d, style: Theme.of(context).textTheme.labelSmall)),
      for (var i = 0; i < leadingBlanks; i++) const SizedBox.shrink(),
    ];

    for (var day = 1; day <= daysInMonth; day++) {
      final key = fmt.format(DateTime(month.year, month.month, day));
      final rec = byDate[key];
      final status = rec == null
          ? null
          : (rec.status == 'absent'
                ? 'absent'
                : (rec.isLate ? 'late' : 'present'));
      final isToday = key == today;
      cells.add(
        Semantics(
          label: '$day${status != null ? ', $status' : ''}',
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: status == null ? null : colors.statusSoftColor(status),
              borderRadius: BorderRadius.circular(10),
              border: isToday
                  ? Border.all(color: colors.brand, width: 2)
                  : null,
            ),
            child: Text(
              '$day',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: status == null
                    ? colors.textTertiary
                    : colors.statusColor(status),
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
      );
    }

    return GridView.count(
      crossAxisCount: 7,
      mainAxisSpacing: 6,
      crossAxisSpacing: 6,
      childAspectRatio: 1.05,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: cells,
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.records});

  final List<AttendanceModel> records;

  @override
  Widget build(BuildContext context) {
    final present = records.where((r) => r.checkIn != null && !r.isLate).length;
    final late = records.where((r) => r.isLate).length;
    final absent = records.where((r) => r.status == 'absent').length;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        StatusBadge(status: 'present', label: 'Present $present'),
        StatusBadge(status: 'late', label: 'Late $late'),
        StatusBadge(status: 'absent', label: 'Absent $absent'),
      ],
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({required this.log});

  final AttendanceModel log;

  @override
  Widget build(BuildContext context) {
    final time = DateFormat('h:mm a');
    String date;
    try {
      date = DateFormat('EEE, d MMM').format(DateTime.parse(log.date));
    } catch (_) {
      date = log.date;
    }
    final inOut = log.checkIn == null
        ? 'No punch'
        : '${time.format(log.checkIn!)} – '
              '${log.checkOut != null ? time.format(log.checkOut!) : 'still in'}';
    final status = log.status == 'absent'
        ? 'absent'
        : (log.isLate ? 'late' : 'present');
    return EntityTile(
      inGroup: true,
      title: date,
      subtitle: log.workDuration != null
          ? '$inOut · ${log.workDurationFormatted}'
          : inOut,
      trailing: StatusBadge(status: status),
    );
  }
}
