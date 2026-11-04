import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:attendance_app/core/di/injection.dart';
import 'package:attendance_app/core/theme/app_colors.dart';
import 'package:attendance_app/core/theme/app_spacing.dart';
import 'package:attendance_app/core/utils/attendance_clock.dart';
import 'package:attendance_app/core/widgets/app_bottom_nav.dart';
import 'package:attendance_app/core/widgets/app_card.dart';
import 'package:attendance_app/core/widgets/app_loader.dart';
import 'package:attendance_app/core/widgets/avatar.dart';
import 'package:attendance_app/core/widgets/entity_tile.dart';
import 'package:attendance_app/core/widgets/section_header.dart';
import 'package:attendance_app/core/widgets/status_badge.dart';
import 'package:attendance_app/data/models/attendance_model.dart';
import 'package:attendance_app/data/models/leave_model.dart';
import 'package:attendance_app/data/models/user_model.dart';
import 'package:attendance_app/domain/repositories/attendance_repository.dart';
import 'package:attendance_app/domain/repositories/employee_repository.dart';
import 'package:attendance_app/domain/repositories/leave_repository.dart';
import 'package:attendance_app/features/admin/admin_analytics.dart';
import 'package:attendance_app/features/admin/attendance_logs.dart';
import 'package:attendance_app/features/admin/company_settings.dart';
import 'package:attendance_app/features/admin/employee_management.dart';
import 'package:attendance_app/features/admin/invite_screen.dart';
import 'package:attendance_app/features/billing/billing_screen.dart';
import 'package:attendance_app/features/billing/paywall.dart';
import 'package:attendance_app/features/admin/leave_management.dart';
import 'package:attendance_app/features/shared/user_provider.dart';

/// The company admin's app shell: Today / Team / Reports / Company tabs.
class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: const [
          _TodayTab(),
          EmployeeManagement(),
          AdminAnalytics(),
          CompanySettingsScreen(),
        ],
      ),
      bottomNavigationBar: AppBottomNav(
        currentIndex: _tab,
        onTap: (i) => setState(() => _tab = i),
        items: const [
          AppNavItem(
            icon: Icons.home_outlined,
            activeIcon: Icons.home_rounded,
            label: 'Today',
          ),
          AppNavItem(
            icon: Icons.groups_outlined,
            activeIcon: Icons.groups_rounded,
            label: 'Team',
          ),
          AppNavItem(icon: Icons.bar_chart_rounded, label: 'Reports'),
          AppNavItem(
            icon: Icons.apartment_outlined,
            activeIcon: Icons.apartment_rounded,
            label: 'Company',
          ),
        ],
      ),
    );
  }
}

class _TodayTab extends StatelessWidget {
  const _TodayTab();

  @override
  Widget build(BuildContext context) {
    final prov = Provider.of<UserProvider>(context);
    final companyId = prov.user?.companyId ?? '';
    final companyName = prov.company?.name ?? 'Your company';

    return SafeArea(
      bottom: false,
      child: StreamBuilder<List<UserModel>>(
        stream: sl<EmployeeRepository>().watchEmployees(companyId),
        builder: (context, empSnap) {
          return StreamBuilder<List<AttendanceModel>>(
            stream: sl<AttendanceRepository>().watchAllLogs(
              companyId,
              dateFilter: AttendanceClock.today(),
            ),
            builder: (context, logSnap) {
              if (empSnap.connectionState == ConnectionState.waiting ||
                  logSnap.connectionState == ConnectionState.waiting) {
                return const AppLoader();
              }
              final employees = empSnap.data ?? const <UserModel>[];
              final logs = logSnap.data ?? const <AttendanceModel>[];
              final byEmployee = {for (final l in logs) l.employeeId: l};
              final inToday = logs.where((l) => l.checkIn != null).toList();
              final late = inToday.where((l) => l.isLate).length;
              final onTime = inToday.length - late;
              final absent = employees
                  .where((e) => byEmployee[e.id]?.checkIn == null)
                  .toList();

              return ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.xxl,
                ),
                children: [
                  Row(
                    children: [
                      Avatar(name: companyName, square: true),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              DateFormat(
                                'EEE, d MMM · h:mm a',
                              ).format(AttendanceClock.now()),
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                            Text(
                              companyName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  PlanBanner(onOpenBilling: () => openBilling(context)),
                  _TodayCard(
                    total: employees.length,
                    onTime: onTime,
                    late: late,
                    absent: absent.length,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: _QuickCard(
                          icon: Icons.list_alt_rounded,
                          title: 'Attendance logs',
                          subtitle: '${inToday.length} punched in today',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AttendanceLogsScreen(),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: StreamBuilder<List<LeaveModel>>(
                          stream: sl<LeaveRepository>().watchPendingLeaves(
                            companyId,
                          ),
                          builder: (context, snap) {
                            final pending = snap.data?.length ?? 0;
                            return _QuickCard(
                              icon: Icons.event_available_rounded,
                              title: 'Leave requests',
                              subtitle: pending == 0
                                  ? 'All caught up'
                                  : '$pending waiting for you',
                              badge: pending,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const LeaveManagement(),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  if (employees.isEmpty) ...[
                    const SectionHeader(title: 'Get started', strong: true),
                    const SizedBox(height: AppSpacing.sm),
                    EntityTile(
                      leading: const IconChip(
                        icon: Icons.person_add_alt_1_rounded,
                      ),
                      title: 'Invite your team',
                      subtitle: 'Share your QR code or add people by phone',
                      chevron: true,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const InviteScreen()),
                      ),
                    ),
                  ] else ...[
                    const SectionHeader(title: 'Needs attention', strong: true),
                    const SizedBox(height: AppSpacing.sm),
                    _Attention(
                      lateLogs: inToday.where((l) => l.isLate).toList(),
                      absent: absent,
                    ),
                  ],
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _TodayCard extends StatelessWidget {
  const _TodayCard({
    required this.total,
    required this.onTime,
    required this.late,
    required this.absent,
  });

  final int total;
  final int onTime;
  final int late;
  final int absent;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final segments = <(int, Color)>[
      (onTime, colors.success),
      (late, const Color(0xFFF59E0B)),
      (absent, colors.danger),
    ].where((s) => s.$1 > 0).toList();

    Widget count(int n, String label, Color dot) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$n',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(label, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ],
      ),
    );

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Today',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Text(
                '$total people',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              height: 10,
              child: segments.isEmpty
                  ? ColoredBox(color: colors.surfaceMuted)
                  : Row(
                      // Stretch so the childless ColoredBoxes fill the bar's
                      // height instead of collapsing to zero.
                      crossAxisAlignment: CrossAxisAlignment.stretch,
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
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              count(onTime, 'On time', colors.success),
              count(late, 'Late', const Color(0xFFF59E0B)),
              count(absent, 'Not in', colors.danger),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickCard extends StatelessWidget {
  const _QuickCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge = 0,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconChip(icon: icon),
              const Spacer(),
              if (badge > 0)
                StatusBadge(status: 'absent', label: '$badge', dot: false),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, color: colors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _Attention extends StatelessWidget {
  const _Attention({required this.lateLogs, required this.absent});

  final List<AttendanceModel> lateLogs;
  final List<UserModel> absent;

  @override
  Widget build(BuildContext context) {
    if (lateLogs.isEmpty && absent.isEmpty) {
      return const AppCard(child: Text('Everyone is in on time today.'));
    }
    final time = DateFormat('h:mm a');
    return AppGroup(
      children: [
        for (final e in absent.take(5))
          EntityTile(
            inGroup: true,
            leading: Avatar(name: e.name, imageUrl: e.avatarUrl),
            title: e.name,
            subtitle:
                'No punch yet · shift starts '
                '${AttendanceClock.formatShiftTime(e.shiftStart)}',
            trailing: const StatusBadge(status: 'absent', label: 'Not in'),
          ),
        for (final l in lateLogs.take(5))
          EntityTile(
            inGroup: true,
            leading: Avatar(name: l.employeeName),
            title: l.employeeName,
            subtitle: 'In at ${time.format(l.checkIn!)}',
            trailing: const StatusBadge(status: 'late'),
          ),
      ],
    );
  }
}
