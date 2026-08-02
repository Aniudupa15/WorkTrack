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
import 'package:attendance_app/features/shared/user_provider.dart';

class LeaveManagement extends StatefulWidget {
  const LeaveManagement({super.key});

  @override
  State<LeaveManagement> createState() => _LeaveManagementState();
}

class _LeaveManagementState extends State<LeaveManagement>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl = TabController(length: 3, vsync: this);

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final companyId = Provider.of<UserProvider>(context).company?.id ?? '';
    final colors = context.colors;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Leave Management'),
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: colors.brand,
          labelColor: colors.textPrimary,
          unselectedLabelColor: colors.textSecondary,
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'Approved'),
            Tab(text: 'Rejected'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _LeaveList(companyId: companyId, statusFilter: 'pending'),
          _LeaveList(companyId: companyId, statusFilter: 'approved'),
          _LeaveList(companyId: companyId, statusFilter: 'rejected'),
        ],
      ),
    );
  }
}

class _LeaveList extends StatelessWidget {
  const _LeaveList({required this.companyId, required this.statusFilter});

  final String companyId;
  final String statusFilter;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<LeaveModel>>(
      stream: sl<LeaveRepository>().watchAllLeaves(companyId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const AppLoader();
        }
        final all = snap.data ?? [];
        final filtered = all.where((l) => l.status == statusFilter).toList();
        if (filtered.isEmpty) {
          return EmptyState(
            icon: Icons.inbox_rounded,
            title: 'No $statusFilter leaves',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(AppSpacing.lg),
          itemCount: filtered.length,
          itemBuilder: (ctx, i) =>
              _LeaveCard(leave: filtered[i], companyId: companyId),
        );
      },
    );
  }
}

class _LeaveCard extends StatelessWidget {
  const _LeaveCard({required this.leave, required this.companyId});

  final LeaveModel leave;
  final String companyId;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
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
                Expanded(
                  child: Text(
                    leave.employeeName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                StatusBadge(status: leave.status),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '${leave.type.toUpperCase()} - ${dateFormat.format(leave.startDate)} to ${dateFormat.format(leave.endDate)} (${leave.durationDays}d)',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Reason: ${leave.reason}',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            if (leave.adminNote != null && leave.adminNote!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Admin note: ${leave.adminNote}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.brand,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            if (leave.status == 'pending') ...[
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _updateStatus(context, 'rejected'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colors.danger,
                        side: BorderSide(color: colors.danger),
                      ),
                      child: const Text('Reject'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _updateStatus(context, 'approved'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.success,
                      ),
                      child: const Text('Approve'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _updateStatus(BuildContext context, String status) async {
    final noteCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${status == "approved" ? "Approve" : "Reject"} Leave'),
        content: TextField(
          controller: noteCtrl,
          decoration: const InputDecoration(hintText: 'Add a note (optional)'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(status == 'approved' ? 'Approve' : 'Reject'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await sl<LeaveRepository>().updateLeaveStatus(
        companyId,
        leave.id,
        status,
        noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
      );
    }
  }
}
