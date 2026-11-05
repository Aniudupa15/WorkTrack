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
import 'package:attendance_app/data/models/leave_model.dart';
import 'package:attendance_app/domain/repositories/attendance_repository.dart';
import 'package:attendance_app/domain/repositories/leave_repository.dart';
import 'package:attendance_app/features/shared/leave_balance.dart';
import 'package:attendance_app/features/shared/today_status.dart';
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
        builder: (context, snapshot) => StreamBuilder<List<LeaveModel>>(
          stream: sl<LeaveRepository>().watchEmployeeLeaves(companyId, uid),
          builder: (context, leaveSnap) {
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
            final statuses = _dayStatuses(
              byDate: byDate,
              leaves: leaveSnap.data ?? const [],
              workingDays:
                  prov.company?.workingDays ?? const [1, 2, 3, 4, 5, 6],
              joined: prov.user?.joinedAt,
              holidays: {for (final h in holidaysOf(prov.company)) h.date},
            );

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
                        statuses: statuses,
                        today: AttendanceClock.today(),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _Legend(statuses: statuses),
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
      ),
    );
  }

  /// One status per day of [_month] up to today: punches first, then
  /// approved leave, then absent on a past working day; 'off' otherwise.
  Map<String, String> _dayStatuses({
    required Map<String, AttendanceModel> byDate,
    required List<LeaveModel> leaves,
    required List<int> workingDays,
    DateTime? joined,
    Set<String> holidays = const {},
  }) {
    final fmt = DateFormat('yyyy-MM-dd');
    final today = AttendanceClock.today();
    final start = joined == null
        ? null
        : fmt.format(DateTime(joined.year, joined.month, joined.day));
    final out = <String, String>{};
    final days = DateTime(_month.year, _month.month + 1, 0).day;
    for (var d = 1; d <= days; d++) {
      final date = DateTime(_month.year, _month.month, d);
      final key = fmt.format(date);
      if (key.compareTo(today) > 0) break;
      final rec = byDate[key];
      if (rec != null && rec.checkIn != null) {
        out[key] = rec.isLate ? 'late' : 'present';
      } else if (leaves.any((l) => onLeaveOn(l, key))) {
        out[key] = 'leave';
      } else if (holidays.contains(key)) {
        out[key] = 'holiday';
      } else if (!workingDays.contains(date.weekday)) {
        out[key] = 'off';
      } else if (key.compareTo(today) < 0 &&
          (start == null || key.compareTo(start) >= 0)) {
        out[key] = 'absent';
      }
    }
    return out;
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.statuses,
    required this.today,
  });

  final DateTime month;
  final Map<String, String> statuses;
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
      final raw = statuses[key];
      final status = raw == 'off' ? null : raw;
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
  const _Legend({required this.statuses});

  final Map<String, String> statuses;

  @override
  Widget build(BuildContext context) {
    int n(String s) => statuses.values.where((v) => v == s).length;
    final present = n('present');
    final late = n('late');
    final leave = n('leave') + n('holiday');
    final absent = n('absent');
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        StatusBadge(status: 'present', label: 'Present $present'),
        StatusBadge(status: 'late', label: 'Late $late'),
        StatusBadge(status: 'leave', label: 'Leave/holiday $leave'),
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
      subtitle: log.locationName == null
          ? inOut
          : '$inOut · ${log.locationName}',
      trailing: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          StatusBadge(status: status),
          if (log.workDuration != null) ...[
            const SizedBox(height: 2),
            Text(
              log.workDurationFormatted,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}
