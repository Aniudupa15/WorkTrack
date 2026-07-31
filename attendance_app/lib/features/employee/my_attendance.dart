import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:attendance_app/core/di/injection.dart';
import 'package:attendance_app/core/theme/app_colors.dart';
import 'package:attendance_app/core/theme/app_spacing.dart';
import 'package:attendance_app/core/widgets/app_loader.dart';
import 'package:attendance_app/core/widgets/empty_state.dart';
import 'package:attendance_app/core/widgets/status_badge.dart';
import 'package:attendance_app/data/models/attendance_model.dart';
import 'package:attendance_app/domain/repositories/attendance_repository.dart';
import 'package:attendance_app/features/shared/user_provider.dart';

class MyAttendanceScreen extends StatelessWidget {
  const MyAttendanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final prov = Provider.of<UserProvider>(context);
    final companyId = prov.company?.id ?? '';
    final uid = prov.user?.id ?? '';
    final colors = context.colors;

    return Scaffold(
      appBar: AppBar(title: const Text('My Attendance')),
      body: StreamBuilder<List<AttendanceModel>>(
        stream: sl<AttendanceRepository>().watchEmployeeHistory(companyId, uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppLoader();
          }

          final logs = snapshot.data ?? [];
          if (logs.isEmpty) {
            return const EmptyState(
              icon: Icons.event_note_rounded,
              title: 'No attendance history yet',
              subtitle: 'Your check-in records will appear here.',
            );
          }

          final currentMonth = DateFormat('yyyy-MM').format(DateTime.now());
          final monthLogs =
              logs.where((l) => l.date.startsWith(currentMonth)).toList();
          final present = monthLogs
              .where((l) => l.status == 'present' || l.status == 'late')
              .length;
          final late = monthLogs.where((l) => l.isLate).length;
          final absent = monthLogs.where((l) => l.status == 'absent').length;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.xl,
                  AppSpacing.xl,
                  AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    _SummaryCard(
                        label: 'Present',
                        value: '$present',
                        color: colors.success),
                    const SizedBox(width: AppSpacing.md),
                    _SummaryCard(
                        label: 'Late', value: '$late', color: colors.warning),
                    const SizedBox(width: AppSpacing.md),
                    _SummaryCard(
                        label: 'Absent',
                        value: '$absent',
                        color: colors.danger),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl,
                    vertical: AppSpacing.sm,
                  ),
                  itemCount: logs.length,
                  itemBuilder: (context, i) => _LogItem(log: logs[i]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.lg,
          horizontal: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _LogItem extends StatelessWidget {
  const _LogItem({required this.log});

  final AttendanceModel log;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final statusColor = colors.statusColor(log.status);
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              log.status == 'absent'
                  ? Icons.person_off
                  : log.isLate
                      ? Icons.history_toggle_off_rounded
                      : Icons.how_to_reg_rounded,
              color: statusColor,
              size: 20,
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  log.date,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    Icon(Icons.login_rounded,
                        size: 12, color: colors.textTertiary),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      log.checkIn != null
                          ? DateFormat('hh:mm a').format(log.checkIn!)
                          : '--:--',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    Icon(Icons.logout_rounded,
                        size: 12, color: colors.textTertiary),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      log.checkOut != null
                          ? DateFormat('hh:mm a').format(log.checkOut!)
                          : '--:--',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (log.workDuration != null) ...[
                      const Spacer(),
                      Text(
                        log.workDurationFormatted,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          StatusBadge(status: log.status),
        ],
      ),
    );
  }
}
