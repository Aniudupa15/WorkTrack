import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:attendance_app/core/di/injection.dart';
import 'package:attendance_app/core/theme/app_colors.dart';
import 'package:attendance_app/core/theme/app_spacing.dart';
import 'package:attendance_app/core/widgets/app_button.dart';
import 'package:attendance_app/core/widgets/app_card.dart';
import 'package:attendance_app/core/widgets/app_loader.dart';
import 'package:attendance_app/core/widgets/avatar.dart';
import 'package:attendance_app/core/widgets/empty_state.dart';
import 'package:attendance_app/core/widgets/pressable.dart';
import 'package:attendance_app/core/widgets/status_badge.dart';
import 'package:attendance_app/data/models/leave_model.dart';
import 'package:attendance_app/domain/repositories/leave_repository.dart';
import 'package:attendance_app/core/widgets/app_page.dart';
import 'package:attendance_app/features/shared/leave_balance.dart';
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
        title: const Text('Leave requests'),
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: colors.brand,
          indicatorSize: TabBarIndicatorSize.label,
          dividerColor: colors.border,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
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
          final (icon, subtitle) = switch (statusFilter) {
            'pending' => (
              Icons.check_circle_outline_rounded,
              'You’re all caught up — no requests waiting for review.',
            ),
            'approved' => (
              Icons.event_available_rounded,
              'Approved leave will be listed here.',
            ),
            _ => (
              Icons.inbox_rounded,
              'Rejected requests will be listed here.',
            ),
          };
          return EmptyState(
            icon: icon,
            title: 'No $statusFilter leaves',
            subtitle: subtitle,
            accent: statusFilter == 'pending' ? context.colors.success : null,
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.lg),
          itemCount: filtered.length,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
          itemBuilder: (ctx, i) =>
              _LeaveCard(leave: filtered[i], companyId: companyId, all: all),
        );
      },
    );
  }
}

class _LeaveCard extends StatelessWidget {
  const _LeaveCard({
    required this.leave,
    required this.companyId,
    this.all = const [],
  });

  final LeaveModel leave;
  final String companyId;

  /// Every request in the company, for balances and overlaps.
  final List<LeaveModel> all;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final dateFormat = DateFormat('d MMM');
    final company = Provider.of<UserProvider>(context).company;
    final workingDays = company?.workingDays ?? const [1, 2, 3, 4, 5, 6];
    final days = leaveDaysOf(leave, workingDays);
    final quota = leaveQuota(company, leave.type);
    final mine = all.where((l) => l.employeeId == leave.employeeId).toList();
    final used = leaveUsed(
      mine.where((l) => l.id != leave.id).toList(),
      leave.type,
      leave.startDate.year,
      workingDays,
    );
    final leftAfter = quota == null ? null : quota - used - days;
    // Others already approved for any of these days.
    final overlap = all
        .where(
          (l) =>
              l.employeeId != leave.employeeId &&
              l.status == 'approved' &&
              !l.startDate.isAfter(leave.endDate) &&
              !l.endDate.isBefore(leave.startDate),
        )
        .map((l) => l.employeeId)
        .toSet()
        .length;
    final length = switch (leave.dayPart) {
      'first_half' => 'first half',
      'second_half' => 'second half',
      _ => '${fmtDays(days)} ${days == 1 ? 'day' : 'days'}',
    };
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Avatar(name: leave.employeeName, size: 40),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      leave.employeeName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${leave.type[0].toUpperCase()}${leave.type.substring(1)} leave',
                      style: TextStyle(
                        color: colors.textTertiary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              StatusBadge(status: leave.status),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              color: colors.surfaceMuted,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: 16,
                  color: colors.textSecondary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    '${dateFormat.format(leave.startDate)} → ${dateFormat.format(leave.endDate)}',
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  length,
                  style: TextStyle(
                    color: colors.brand,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            leave.reason,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: colors.textPrimary),
          ),
          if (leave.status == 'pending' && leftAfter != null) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${StatusBadge.humanise(leave.type)} left after this',
                    style: TextStyle(color: colors.textSecondary, fontSize: 13),
                  ),
                ),
                Text(
                  leftAfter < 0
                      ? '${fmtDays(-leftAfter)} over $quota'
                      : '${fmtDays(leftAfter)} of $quota',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: leftAfter < 0 ? colors.danger : null,
                  ),
                ),
              ],
            ),
          ],
          if (leave.status == 'pending' && overlap > 0) ...[
            const SizedBox(height: AppSpacing.md),
            AppBanner(
              icon: Icons.warning_amber_rounded,
              tone: BannerTone.warning,
              child: Text(
                overlap == 1
                    ? '1 other person is off on these days.'
                    : '$overlap others are off on these days.',
              ),
            ),
          ],
          if (leave.adminNote != null && leave.adminNote!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Note: ${leave.adminNote}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          if (leave.status == 'pending') ...[
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'Reject',
                    icon: Icons.close_rounded,
                    variant: AppButtonVariant.secondary,
                    size: AppButtonSize.small,
                    onPressed: () => _updateStatus(context, 'rejected'),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _ApproveButton(
                    onPressed: () => _updateStatus(context, 'approved'),
                  ),
                ),
              ],
            ),
          ],
        ],
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

/// Solid success-tinted "Approve" button — matches [AppButton]'s metrics but
/// carries the success colour, which the standard variants don't expose.
class _ApproveButton extends StatelessWidget {
  const _ApproveButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final fg = AppColors.onColor(colors.brand);
    return Pressable(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Container(
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colors.brand,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_rounded, size: 16, color: fg),
            const SizedBox(width: 6),
            Text(
              'Approve',
              style: TextStyle(
                color: fg,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
