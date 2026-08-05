import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:attendance_app/core/di/injection.dart';
import 'package:attendance_app/core/theme/app_colors.dart';
import 'package:attendance_app/core/theme/app_spacing.dart';
import 'package:attendance_app/core/widgets/app_card.dart';
import 'package:attendance_app/core/widgets/app_loader.dart';
import 'package:attendance_app/core/widgets/avatar.dart';
import 'package:attendance_app/core/widgets/empty_state.dart';
import 'package:attendance_app/core/widgets/entity_tile.dart';
import 'package:attendance_app/core/widgets/section_header.dart';
import 'package:attendance_app/core/widgets/status_badge.dart';
import 'package:attendance_app/data/models/attendance_model.dart';
import 'package:attendance_app/data/models/user_model.dart';
import 'package:attendance_app/domain/repositories/attendance_repository.dart';
import 'package:attendance_app/domain/repositories/employee_repository.dart';
import 'package:attendance_app/features/admin/admin_analytics.dart';
import 'package:attendance_app/features/admin/attendance_logs.dart';
import 'package:attendance_app/features/admin/employee_management.dart';
import 'package:attendance_app/features/admin/leave_management.dart';
import 'package:attendance_app/features/shared/account_menu.dart';
import 'package:attendance_app/features/shared/user_provider.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final employeeRepo = sl<EmployeeRepository>();
    final attendanceRepo = sl<AttendanceRepository>();
    final companyId = userProvider.user?.companyId ?? '';

    return Scaffold(
      appBar: AppBar(
        titleSpacing: AppSpacing.xxl,
        title: Text(userProvider.company?.name ?? 'Workspace'),
        actions: const [
          AccountMenu(),
          SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: StreamBuilder<List<UserModel>>(
        stream: employeeRepo.watchEmployees(companyId),
        builder: (context, employeesSnapshot) {
          return StreamBuilder<List<AttendanceModel>>(
            stream: attendanceRepo.watchAllLogs(companyId),
            builder: (context, attendanceSnapshot) {
              if (employeesSnapshot.connectionState ==
                      ConnectionState.waiting ||
                  attendanceSnapshot.connectionState ==
                      ConnectionState.waiting) {
                return const AppLoader();
              }

              final employees = employeesSnapshot.data ?? [];
              final allLogs = attendanceSnapshot.data ?? [];
              final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
              final todayLogs = allLogs
                  .where((log) => log.date == today)
                  .toList();

              final totalEmployees = employees.length;
              final presentToday = todayLogs
                  .where((l) => l.status == 'present' || l.status == 'late')
                  .length;
              final lateCheckins = todayLogs
                  .where((log) => log.status == 'late' || log.isLate)
                  .length;
              final absentToday = (totalEmployees - presentToday).clamp(
                0,
                totalEmployees,
              );
              final onTime = (presentToday - lateCheckins).clamp(
                0,
                totalEmployees,
              );
              final firstName =
                  userProvider.user?.name.split(' ').first ?? 'Admin';

              return ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xxl,
                  AppSpacing.md,
                  AppSpacing.xxl,
                  40,
                ),
                children: [
                  _Greeting(name: firstName),
                  const SizedBox(height: AppSpacing.xxl),
                  _TodayPulse(
                    total: totalEmployees,
                    present: presentToday,
                    onTime: onTime,
                    late: lateCheckins,
                    absent: absentToday,
                  ),
                  const SizedBox(height: AppSpacing.xxxl),
                  const SectionHeader(
                    title: 'Manage',
                    icon: Icons.grid_view_rounded,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const _QuickActionsGrid(),
                  const SizedBox(height: AppSpacing.xxxl),
                  const SectionHeader(
                    title: 'Recent activity',
                    icon: Icons.bolt_rounded,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _RecentActivity(logs: todayLogs),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

/// Time-of-day aware greeting with today's date — the "good morning" moment.
class _Greeting extends StatelessWidget {
  const _Greeting({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final hour = DateTime.now().hour;
    final partOfDay = hour < 12
        ? 'Good morning'
        : hour < 17
        ? 'Good afternoon'
        : 'Good evening';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          DateFormat('EEEE, d MMMM').format(DateTime.now()).toUpperCase(),
          style: text.bodySmall?.copyWith(
            letterSpacing: 1.8,
            fontWeight: FontWeight.w700,
            color: colors.textTertiary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text('$partOfDay,\n$name.', style: text.displaySmall),
      ],
    );
  }
}

/// The focal "Today" card: a present-rate headline, a segmented attendance
/// bar (on-time / late / absent), and an inline legend. Replaces the old 2×2
/// grid of identical stat cards with one scannable summary.
class _TodayPulse extends StatelessWidget {
  const _TodayPulse({
    required this.total,
    required this.present,
    required this.onTime,
    required this.late,
    required this.absent,
  });

  final int total;
  final int present;
  final int onTime;
  final int late;
  final int absent;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final rate = total == 0 ? 0 : ((present / total) * 100).round();

    return AppCard(
      elevated: true,
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Today's attendance",
                      style: text.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '$present',
                          style: text.displaySmall?.copyWith(
                            fontFamily: 'PlusJakartaSans',
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1,
                          ),
                        ),
                        Text(
                          '  of $total present',
                          style: text.bodyMedium?.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: colors.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  '$rate%',
                  style: TextStyle(
                    color: colors.success,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          _SegmentBar(onTime: onTime, late: late, absent: absent, total: total),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              _Legend(color: colors.success, label: 'On time', value: onTime),
              _Legend(color: colors.warning, label: 'Late', value: late),
              _Legend(color: colors.danger, label: 'Absent', value: absent),
            ],
          ),
        ],
      ),
    );
  }
}

class _SegmentBar extends StatelessWidget {
  const _SegmentBar({
    required this.onTime,
    required this.late,
    required this.absent,
    required this.total,
  });

  final int onTime;
  final int late;
  final int absent;
  final int total;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    if (total == 0) {
      return Container(
        height: 10,
        decoration: BoxDecoration(
          color: colors.surfaceMuted,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
      );
    }
    final segments = <(int, Color)>[
      (onTime, colors.success),
      (late, colors.warning),
      (absent, colors.danger),
    ].where((s) => s.$1 > 0).toList();

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: SizedBox(
        height: 10,
        child: Row(
          children: [
            for (var i = 0; i < segments.length; i++) ...[
              if (i > 0) const SizedBox(width: 2),
              Expanded(
                flex: segments[i].$1,
                child: ColoredBox(color: segments[i].$2),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({
    required this.color,
    required this.label,
    required this.value,
  });

  final Color color;
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Expanded(
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            '$value',
            style: TextStyle(
              color: colors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: colors.textTertiary, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

/// The four management destinations as a compact 2-up grid of tappable tiles.
class _QuickActionsGrid extends StatelessWidget {
  const _QuickActionsGrid();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final actions = [
      (
        'Employees',
        'Directory & accounts',
        Icons.people_alt_rounded,
        colors.info,
        () => const EmployeeManagement(),
      ),
      (
        'Attendance',
        'Logs & reports',
        Icons.history_edu_rounded,
        colors.brand,
        () => const AttendanceLogsScreen(),
      ),
      (
        'Leaves',
        'Review requests',
        Icons.event_busy_rounded,
        colors.warning,
        () => const LeaveManagement(),
      ),
      (
        'Analytics',
        'Charts & trends',
        Icons.insights_rounded,
        colors.success,
        () => const AdminAnalytics(),
      ),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: AppSpacing.md,
      mainAxisSpacing: AppSpacing.md,
      childAspectRatio: 1.35,
      children: [
        for (final a in actions)
          _QuickAction(
            title: a.$1,
            subtitle: a.$2,
            icon: a.$3,
            color: a.$4,
            builder: a.$5,
          ),
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.builder,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Widget Function() builder;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      onTap: () =>
          Navigator.push(context, MaterialPageRoute(builder: (_) => builder())),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconChip(icon: icon, color: color),
          const Spacer(),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: colors.textTertiary, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _RecentActivity extends StatelessWidget {
  const _RecentActivity({required this.logs});

  final List<AttendanceModel> logs;

  @override
  Widget build(BuildContext context) {
    if (logs.isEmpty) {
      return const AppCard(
        child: EmptyState(
          icon: Icons.inbox_rounded,
          title: 'No check-ins yet',
          subtitle: 'Today’s check-ins will appear here as your team arrives.',
        ),
      );
    }
    final visible = logs.take(6).toList();
    return Column(
      children: [
        for (final log in visible) ...[
          EntityTile(
            leading: Avatar(
              name: log.employeeName.isNotEmpty
                  ? log.employeeName
                  : log.employeeId,
              size: 40,
            ),
            title: log.employeeName.isNotEmpty
                ? log.employeeName
                : log.employeeId.substring(0, 8),
            subtitle: log.checkIn != null
                ? 'Checked in · ${DateFormat('hh:mm a').format(log.checkIn!)}'
                : 'Checked in',
            trailing: StatusBadge(status: log.status),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }
}
