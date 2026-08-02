import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:attendance_app/core/di/injection.dart';
import 'package:attendance_app/core/theme/app_colors.dart';
import 'package:attendance_app/core/theme/app_spacing.dart';
import 'package:attendance_app/core/widgets/app_loader.dart';
import 'package:attendance_app/core/widgets/empty_state.dart';
import 'package:attendance_app/core/widgets/section_header.dart';
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
    final colors = context.colors;
    final companyId = userProvider.user?.companyId ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(userProvider.company?.name ?? 'Admin Dashboard'),
            Text(
              'Workspace Overview',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
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
              final absentToday = totalEmployees - presentToday;
              final lateCheckins = todayLogs
                  .where((log) => log.status == 'late' || log.isLate)
                  .length;
              final firstName =
                  userProvider.user?.name.split(' ').first ?? 'Admin';

              return SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome back, $firstName 👋',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    _StatsGrid(
                      total: totalEmployees,
                      present: presentToday,
                      absent: absentToday < 0 ? 0 : absentToday,
                      late: lateCheckins,
                    ),
                    const SizedBox(height: 40),
                    const SectionHeader(
                      title: 'Management',
                      icon: Icons.settings_suggest_rounded,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _ActionButton(
                      title: 'Employee Directory',
                      subtitle: 'Add, edit or remove staff accounts',
                      icon: Icons.people_alt_rounded,
                      color: colors.info,
                      builder: () => const EmployeeManagement(),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _ActionButton(
                      title: 'Attendance History',
                      subtitle: 'Detailed logs and check-in reports',
                      icon: Icons.history_edu_rounded,
                      color: colors.danger,
                      builder: () => const AttendanceLogsScreen(),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _ActionButton(
                      title: 'Leave Requests',
                      subtitle: 'Review and approve employee leaves',
                      icon: Icons.event_busy_rounded,
                      color: colors.warning,
                      builder: () => const LeaveManagement(),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _ActionButton(
                      title: 'Analytics',
                      subtitle: 'Attendance charts and statistics',
                      icon: Icons.bar_chart_rounded,
                      color: colors.success,
                      builder: () => const AdminAnalytics(),
                    ),
                    const SizedBox(height: 40),
                    const SectionHeader(
                      title: 'Recent Activity',
                      icon: Icons.bolt_rounded,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _RecentActivity(logs: todayLogs),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({
    required this.total,
    required this.present,
    required this.absent,
    required this.late,
  });

  final int total;
  final int present;
  final int absent;
  final int late;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: AppSpacing.lg,
      mainAxisSpacing: AppSpacing.lg,
      childAspectRatio: 1.5,
      children: [
        _StatCard(
          title: 'Fleet Size',
          value: '$total',
          color: colors.brand,
          icon: Icons.group_rounded,
        ),
        _StatCard(
          title: 'Checked In',
          value: '$present',
          color: colors.success,
          icon: Icons.how_to_reg_rounded,
        ),
        _StatCard(
          title: 'Absent',
          value: '$absent',
          color: colors.danger,
          icon: Icons.person_off_rounded,
        ),
        _StatCard(
          title: 'Delayed',
          value: '$late',
          color: colors.warning,
          icon: Icons.alarm_on_rounded,
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String title;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 28),
            const Spacer(),
            Text(title, style: Theme.of(context).textTheme.bodySmall),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
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
    return InkWell(
      onTap: () =>
          Navigator.push(context, MaterialPageRoute(builder: (_) => builder())),
      borderRadius: BorderRadius.circular(AppRadius.xl),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: AppSpacing.xl),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: colors.textTertiary),
          ],
        ),
      ),
    );
  }
}

class _RecentActivity extends StatelessWidget {
  const _RecentActivity({required this.logs});

  final List<AttendanceModel> logs;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    if (logs.isEmpty) {
      return const Card(
        child: EmptyState(
          icon: Icons.inbox_rounded,
          title: 'No check-ins today yet',
        ),
      );
    }
    final visible = logs.take(5).toList();
    return Column(
      children: [
        for (final log in visible)
          Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.md),
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: colors.border),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: colors
                      .statusColor(log.status)
                      .withValues(alpha: 0.15),
                  radius: 18,
                  child: Icon(
                    log.isLate
                        ? Icons.access_time_rounded
                        : Icons.check_rounded,
                    size: 16,
                    color: colors.statusColor(log.status),
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        log.employeeName.isNotEmpty
                            ? log.employeeName
                            : log.employeeId.substring(0, 8),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      if (log.checkIn != null)
                        Text(
                          DateFormat('hh:mm a').format(log.checkIn!),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: colors
                        .statusColor(log.status)
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Text(
                    log.status,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: colors.statusColor(log.status),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
