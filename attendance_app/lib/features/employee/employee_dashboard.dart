import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:attendance_app/core/di/injection.dart';
import 'package:attendance_app/core/theme/app_colors.dart';
import 'package:attendance_app/core/theme/app_spacing.dart';
import 'package:attendance_app/core/widgets/app_loader.dart';
import 'package:attendance_app/core/widgets/section_header.dart';
import 'package:attendance_app/data/models/attendance_model.dart';
import 'package:attendance_app/domain/repositories/attendance_repository.dart';
import 'package:attendance_app/features/employee/mark_attendance.dart';
import 'package:attendance_app/features/employee/my_attendance.dart';
import 'package:attendance_app/features/employee/my_leaves.dart';
import 'package:attendance_app/features/shared/user_provider.dart';

class EmployeeDashboard extends StatelessWidget {
  const EmployeeDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final attendanceRepo = sl<AttendanceRepository>();
    final colors = context.colors;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Workspace'),
        actions: [
          IconButton(
            icon: Icon(Icons.logout_rounded, color: colors.danger),
            onPressed: () => userProvider.signOut(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ProfileHeader(provider: userProvider),
            const SizedBox(height: AppSpacing.xxxl),
            const SectionHeader(
              title: "Today's Journey",
              icon: Icons.today_rounded,
            ),
            const SizedBox(height: AppSpacing.lg),
            _TodayStatus(repo: attendanceRepo, provider: userProvider),
            const SizedBox(height: 40),
            const SectionHeader(
              title: 'Quick Actions',
              icon: Icons.bolt_rounded,
            ),
            const SizedBox(height: AppSpacing.lg),
            _ActionCard(
              title: 'Mark Attendance',
              subtitle: 'Check-in or Check-out for today',
              icon: Icons.location_on_rounded,
              color: colors.brand,
              builder: () => const MarkAttendanceScreen(),
            ),
            const SizedBox(height: AppSpacing.lg),
            _ActionCard(
              title: 'Attendance History',
              subtitle: 'View your past check-in records',
              icon: Icons.history_rounded,
              color: colors.info,
              builder: () => const MyAttendanceScreen(),
            ),
            const SizedBox(height: AppSpacing.lg),
            _ActionCard(
              title: 'My Leaves',
              subtitle: 'Request and track leave applications',
              icon: Icons.event_busy_rounded,
              color: colors.warning,
              builder: () => const MyLeaves(),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.provider});

  final UserProvider provider;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final name = provider.user?.name ?? '';
    final firstName = name.isNotEmpty ? name.split(' ').first : 'there';
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colors.brand, const Color(0xFF4F46E5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.xxl),
        boxShadow: [
          BoxShadow(
            color: colors.brand.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.xs),
            decoration: BoxDecoration(
              color: colors.onBrand.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: CircleAvatar(
              radius: 32,
              backgroundColor: colors.onBrand,
              child: Icon(Icons.person_rounded, size: 40, color: colors.brand),
            ),
          ),
          const SizedBox(width: AppSpacing.xl),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hello, $firstName 👋',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: colors.onBrand,
                  ),
                ),
                Text(
                  provider.user?.email ?? '',
                  style: TextStyle(
                    color: colors.onBrand.withValues(alpha: 0.85),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: colors.onBrand.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Text(
                    'Shift: ${provider.user?.shiftStart} - ${provider.user?.shiftEnd}',
                    style: TextStyle(
                      color: colors.onBrand,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TodayStatus extends StatelessWidget {
  const _TodayStatus({required this.repo, required this.provider});

  final AttendanceRepository repo;
  final UserProvider provider;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return FutureBuilder<AttendanceModel?>(
      future: repo.getTodayAttendance(
        provider.company?.id ?? '',
        provider.user?.id ?? '',
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(height: 120, child: AppLoader());
        }
        final attendance = snapshot.data;
        final isCheckedIn = attendance != null;
        final isCheckedOut = attendance?.checkOut != null;

        return Container(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(AppRadius.xxl),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            children: [
              _StatusItem(
                label: 'Check In',
                active: isCheckedIn,
                time: attendance?.checkIn,
                color: colors.success,
              ),
              Expanded(
                child: Container(
                  height: 2,
                  margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        isCheckedIn ? colors.success : colors.border,
                        isCheckedOut ? colors.success : colors.border,
                      ],
                    ),
                  ),
                ),
              ),
              _StatusItem(
                label: 'Check Out',
                active: isCheckedOut,
                time: attendance?.checkOut,
                color: colors.danger,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatusItem extends StatelessWidget {
  const _StatusItem({
    required this.label,
    required this.active,
    required this.time,
    required this.color,
  });

  final String label;
  final bool active;
  final DateTime? time;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: active ? color.withValues(alpha: 0.12) : colors.surfaceMuted,
            shape: BoxShape.circle,
          ),
          child: Icon(
            active
                ? Icons.check_circle_rounded
                : Icons.radio_button_off_rounded,
            color: active ? color : colors.textTertiary,
            size: 28,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        Text(
          time != null ? DateFormat('hh:mm a').format(time!) : '--:--',
          style: TextStyle(fontSize: 12, color: colors.textTertiary),
        ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
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
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: colors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}
