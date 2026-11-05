import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:attendance_app/core/di/injection.dart';
import 'package:attendance_app/core/theme/app_colors.dart';
import 'package:attendance_app/core/theme/app_spacing.dart';
import 'package:attendance_app/core/utils/attendance_clock.dart';
import 'package:attendance_app/core/utils/platform_info.dart';
import 'package:attendance_app/core/widgets/app_bottom_nav.dart';
import 'package:attendance_app/core/widgets/app_button.dart';
import 'package:attendance_app/core/widgets/app_card.dart';
import 'package:attendance_app/core/widgets/avatar.dart';
import 'package:attendance_app/core/widgets/entity_tile.dart';
import 'package:attendance_app/core/widgets/metric_tile.dart';
import 'package:attendance_app/core/widgets/section_header.dart';
import 'package:attendance_app/core/widgets/status_badge.dart';
import 'package:attendance_app/data/models/attendance_model.dart';
import 'package:attendance_app/data/models/leave_model.dart';
import 'package:attendance_app/domain/repositories/attendance_repository.dart';
import 'package:attendance_app/domain/repositories/leave_repository.dart';
import 'package:attendance_app/features/employee/leave_request.dart';
import 'package:attendance_app/features/employee/mark_attendance.dart';
import 'package:attendance_app/features/employee/my_attendance.dart';
import 'package:attendance_app/features/employee/my_leaves.dart';
import 'package:attendance_app/features/shared/leave_balance.dart';
import 'package:attendance_app/features/shared/profile_screen.dart';
import 'package:attendance_app/features/shared/today_status.dart';
import 'package:attendance_app/features/shared/user_provider.dart';

/// The employee app shell: Home / Attendance / Leaves / Profile tabs.
class EmployeeDashboard extends StatefulWidget {
  const EmployeeDashboard({super.key});

  @override
  State<EmployeeDashboard> createState() => _EmployeeDashboardState();
}

class _EmployeeDashboardState extends State<EmployeeDashboard> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: [
          _HomeTab(onOpenTab: (i) => setState(() => _tab = i)),
          const MyAttendanceScreen(),
          const MyLeaves(),
          const ProfileScreen(),
        ],
      ),
      bottomNavigationBar: AppBottomNav(
        currentIndex: _tab,
        onTap: (i) => setState(() => _tab = i),
        items: const [
          AppNavItem(
            icon: Icons.home_outlined,
            activeIcon: Icons.home_rounded,
            label: 'Home',
          ),
          AppNavItem(
            icon: Icons.calendar_month_outlined,
            activeIcon: Icons.calendar_month_rounded,
            label: 'Attendance',
          ),
          AppNavItem(
            icon: Icons.beach_access_outlined,
            activeIcon: Icons.beach_access_rounded,
            label: 'Leaves',
          ),
          AppNavItem(
            icon: Icons.person_outline_rounded,
            activeIcon: Icons.person_rounded,
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class _HomeTab extends StatefulWidget {
  const _HomeTab({required this.onOpenTab});

  final ValueChanged<int> onOpenTab;

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  final _repo = sl<AttendanceRepository>();
  late final _prov = Provider.of<UserProvider>(context, listen: false);
  late final Stream<List<AttendanceModel>> _history = _repo
      .watchEmployeeHistory(_prov.company?.id ?? '', _prov.user?.id ?? '');
  late final Stream<List<LeaveModel>> _leaves = sl<LeaveRepository>()
      .watchEmployeeLeaves(_prov.company?.id ?? '', _prov.user?.id ?? '');
  late Future<AttendanceModel?> _today;

  @override
  void initState() {
    super.initState();
    _today = _loadToday();
  }

  Future<AttendanceModel?> _loadToday() {
    final prov = Provider.of<UserProvider>(context, listen: false);
    return _repo.getTodayAttendance(
      prov.company?.id ?? '',
      prov.user?.id ?? '',
    );
  }

  Future<void> _openPunch() async {
    if (!PlatformInfo.canPunch) {
      // A desktop browser has no GPS: its Wi-Fi/IP location is rarely
      // within the 100 m accuracy a punch needs.
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Punch in from your phone'),
          content: const Text(
            'Punching needs your phone’s GPS. Open PunchIn on your phone — '
            'the app or the website — to punch in or out. You can see your '
            'attendance and leave here.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MarkAttendanceScreen()),
    );
    if (mounted) setState(() => _today = _loadToday());
  }

  String get _greeting {
    final h = AttendanceClock.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final prov = Provider.of<UserProvider>(context);
    final user = prov.user!;
    final colors = context.colors;
    final firstName = user.name.split(' ').first;

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: () async {
          setState(() => _today = _loadToday());
          await _today;
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.xxl,
          ),
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: () => widget.onOpenTab(3),
                  child: Avatar(name: user.name, imageUrl: user.avatarUrl),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat('EEE, d MMM').format(AttendanceClock.now()),
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                      Text(
                        '$_greeting, $firstName',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            // The live history wins, so the card flips to "checked in" the
            // moment a punch is saved; the one-off read covers first paint.
            StreamBuilder<List<AttendanceModel>>(
              stream: _history,
              builder: (context, hist) => FutureBuilder<AttendanceModel?>(
                future: _today,
                builder: (context, snap) {
                  final day = AttendanceClock.today();
                  final live = hist.data
                      ?.where((h) => h.date == day)
                      .firstOrNull;
                  return _ShiftCard(
                    loading:
                        !hist.hasData &&
                        snap.connectionState == ConnectionState.waiting,
                    today: live ?? snap.data,
                    onPunch: _openPunch,
                  );
                },
              ),
            ),
            SectionHeader(
              title:
                  '${DateFormat('MMMM').format(AttendanceClock.now())} so far',
              strong: true,
              actionLabel: 'View all',
              onAction: () => widget.onOpenTab(1),
            ),
            const SizedBox(height: AppSpacing.sm),
            StreamBuilder<List<LeaveModel>>(
              stream: _leaves,
              builder: (context, leaveSnap) {
                final leaves = leaveSnap.data ?? const <LeaveModel>[];
                final workingDays =
                    prov.company?.workingDays ?? const [1, 2, 3, 4, 5, 6];
                final now = AttendanceClock.now();
                final casualLeft =
                    (leaveQuota(prov.company, 'casual') ?? 0) -
                    leaveUsed(
                      leaves,
                      'casual',
                      now.year,
                      workingDays,
                      pending: true,
                    );
                // Leave days this month up to today.
                final monthStart = DateTime(now.year, now.month);
                final today = DateTime(now.year, now.month, now.day);
                var leaveDaysSoFar = 0;
                for (
                  var d = monthStart;
                  !d.isAfter(today);
                  d = d.add(const Duration(days: 1))
                ) {
                  final key = DateFormat('yyyy-MM-dd').format(d);
                  if (leaves.any((l) => onLeaveOn(l, key))) leaveDaysSoFar++;
                }
                return Column(
                  children: [
                    StreamBuilder<List<AttendanceModel>>(
                      stream: _history,
                      builder: (context, snap) {
                        final month = DateFormat('yyyy-MM').format(now);
                        final logs = (snap.data ?? const <AttendanceModel>[])
                            .where((l) => l.date.startsWith(month))
                            .toList();
                        final late = logs.where((l) => l.isLate).length;
                        final present =
                            logs.where((l) => l.checkIn != null).length - late;
                        return MetricRow(
                          tiles: [
                            MetricTile(
                              label: 'Present',
                              value: '$present',
                              dotColor: colors.success,
                            ),
                            MetricTile(
                              label: 'Late',
                              value: '$late',
                              dotColor: colors.warning,
                            ),
                            MetricTile(
                              label: 'Leave',
                              value: '$leaveDaysSoFar',
                              dotColor: colors.info,
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    EntityTile(
                      leading: IconChip(
                        icon: Icons.event_available_rounded,
                        color: colors.info,
                        background: colors.infoSoft,
                      ),
                      title: 'Plan time off',
                      subtitle: casualLeft <= 0
                          ? 'No casual days left this year'
                          : '${fmtDays(casualLeft)} casual '
                                '${casualLeft == 1 ? 'day' : 'days'} left',
                      chevron: true,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const LeaveRequest()),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Today's shift with the punch call-to-action, in the state the day is in:
/// not in yet → checked in → done.
class _ShiftCard extends StatelessWidget {
  const _ShiftCard({
    required this.loading,
    required this.today,
    required this.onPunch,
  });

  final bool loading;
  final AttendanceModel? today;
  final VoidCallback onPunch;

  @override
  Widget build(BuildContext context) {
    final prov = Provider.of<UserProvider>(context);
    final user = prov.user!;
    final sites = prov.sites;
    final colors = context.colors;
    final time = DateFormat('h:mm a');
    final checkedIn = today?.checkIn != null;
    final done = today?.checkOut != null;
    final startMin = AttendanceClock.parseMinutes(user.shiftStart) ?? 540;
    final endMin = AttendanceClock.parseMinutes(user.shiftEnd) ?? 1080;
    final graceEnd = startMin + (prov.company?.lateAfterMinutes ?? 15);
    final nowMin = AttendanceClock.minutesOfDay(AttendanceClock.now());
    const fmt = AttendanceClock.formatShiftTime;
    final closed = !checkedIn && !done && nowMin >= endMin;

    final Widget pill;
    final String caption;
    if (done) {
      pill = const StatusBadge(status: 'present', label: 'Done for today');
      caption = 'Worked ${today!.workDurationFormatted}';
    } else if (checkedIn) {
      pill = StatusBadge(
        status: today!.isLate ? 'late' : 'present',
        label: 'In since ${time.format(today!.checkIn!)}',
      );
      caption = 'Shift ends at ${fmt(user.shiftEnd)}';
    } else if (closed) {
      pill = const StatusBadge(status: 'absent', label: 'Not punched');
      caption = 'Your shift has ended — punch-in is closed for today';
    } else {
      pill = const StatusBadge(status: 'pending', label: 'Not in yet');
      caption = nowMin <= graceEnd
          ? 'On time until ${AttendanceClock.formatMinutes(graceEnd)}'
          : 'You’ll be marked late';
    }

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Today’s shift',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      '${fmt(user.shiftStart)} – ${fmt(user.shiftEnd)}',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
              if (!loading) pill,
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: colors.surfaceMuted,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              children: [
                Icon(Icons.location_on_outlined, size: 18, color: colors.brand),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    sites.isEmpty
                        ? 'No work location assigned yet'
                        : sites.length == 1
                        ? sites.first.name
                        : '${sites.first.name} + ${sites.length - 1} more',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (loading)
            const SizedBox(
              height: 60,
              child: Center(child: CircularProgressIndicator()),
            )
          else
            SizedBox(
              height: 60,
              child: AppButton(
                label: done
                    ? 'See today'
                    : checkedIn
                    ? 'Punch out'
                    : (closed ? 'Shift over' : 'Punch in'),
                icon: done
                    ? Icons.check_circle_outline_rounded
                    : (checkedIn ? Icons.logout_rounded : Icons.login_rounded),
                variant: done || closed
                    ? AppButtonVariant.secondary
                    : AppButtonVariant.primary,
                onPressed: onPunch,
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            caption,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}
