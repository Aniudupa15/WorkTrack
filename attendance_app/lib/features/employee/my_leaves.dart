import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:attendance_app/core/di/injection.dart';
import 'package:attendance_app/core/theme/app_colors.dart';
import 'package:attendance_app/core/theme/app_spacing.dart';
import 'package:attendance_app/core/widgets/app_loader.dart';
import 'package:attendance_app/core/widgets/empty_state.dart';
import 'package:attendance_app/core/widgets/status_badge.dart';
import 'package:attendance_app/data/models/leave_model.dart';
import 'package:attendance_app/domain/repositories/leave_repository.dart';
import 'package:attendance_app/features/employee/leave_request.dart';
import 'package:attendance_app/features/shared/user_provider.dart';

class MyLeaves extends StatelessWidget {
  const MyLeaves({super.key});

  @override
  Widget build(BuildContext context) {
    final prov = Provider.of<UserProvider>(context);
    final companyId = prov.company?.id ?? '';
    final uid = prov.user?.id ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('My Leaves')),
      body: StreamBuilder<List<LeaveModel>>(
        stream: sl<LeaveRepository>().watchEmployeeLeaves(companyId, uid),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const AppLoader();
          }
          final leaves = snap.data ?? [];
          if (leaves.isEmpty) {
            return const EmptyState(
              icon: Icons.beach_access_rounded,
              title: 'No leave requests yet',
              subtitle: 'Tap + to request time off.',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: leaves.length,
            itemBuilder: (ctx, i) => _LeaveCard(leave: leaves[i]),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const LeaveRequest()),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _LeaveCard extends StatelessWidget {
  const _LeaveCard({required this.leave});

  final LeaveModel leave;

  IconData get _statusIcon {
    switch (leave.status) {
      case 'approved':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      default:
        return Icons.hourglass_empty;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final statusColor = colors.statusColor(leave.status);
    final dateFormat = DateFormat('dd MMM yyyy');
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_statusIcon, color: statusColor, size: 20),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  leave.type.toUpperCase(),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const Spacer(),
                StatusBadge(status: leave.status),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              '${dateFormat.format(leave.startDate)} - ${dateFormat.format(leave.endDate)}  (${leave.durationDays}d)',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(leave.reason, style: Theme.of(context).textTheme.bodyLarge),
            if (leave.adminNote != null && leave.adminNote!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: colors.surfaceMuted,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Row(
                  children: [
                    Icon(Icons.comment, size: 14, color: colors.brand),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Admin: ${leave.adminNote}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
