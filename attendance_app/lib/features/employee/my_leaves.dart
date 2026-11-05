import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:attendance_app/core/di/injection.dart';
import 'package:attendance_app/core/theme/app_colors.dart';
import 'package:attendance_app/core/theme/app_spacing.dart';
import 'package:attendance_app/core/utils/attendance_clock.dart';
import 'package:attendance_app/core/widgets/app_button.dart';
import 'package:attendance_app/core/widgets/app_card.dart';
import 'package:attendance_app/core/widgets/app_chip.dart';
import 'package:attendance_app/core/widgets/app_loader.dart';
import 'package:attendance_app/core/widgets/app_page.dart';
import 'package:attendance_app/core/widgets/empty_state.dart';
import 'package:attendance_app/core/widgets/status_badge.dart';
import 'package:attendance_app/data/models/leave_model.dart';
import 'package:attendance_app/domain/repositories/leave_repository.dart';
import 'package:attendance_app/features/employee/leave_request.dart';
import 'package:attendance_app/features/shared/leave_balance.dart';
import 'package:attendance_app/features/shared/user_provider.dart';

/// The employee's leave requests with days taken this year per type and a
/// status filter.
class MyLeaves extends StatefulWidget {
  const MyLeaves({super.key});

  @override
  State<MyLeaves> createState() => _MyLeavesState();
}

class _MyLeavesState extends State<MyLeaves> {
  String _filter = 'all';

  void _request() => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const LeaveRequest()),
  );

  @override
  Widget build(BuildContext context) {
    final prov = Provider.of<UserProvider>(context);
    final companyId = prov.company?.id ?? '';
    final uid = prov.user?.id ?? '';
    final requestButton = AppButton(
      label: 'Request',
      size: AppButtonSize.small,
      expand: false,
      onPressed: _request,
    );

    return Scaffold(
      appBar: Navigator.of(context).canPop()
          ? AppBar(
              title: const Text('Leaves'),
              actions: [
                requestButton,
                const SizedBox(width: AppSpacing.md),
              ],
            )
          : TabHeader(title: 'Leaves', actions: [requestButton]),
      body: StreamBuilder<List<LeaveModel>>(
        stream: sl<LeaveRepository>().watchEmployeeLeaves(companyId, uid),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const AppLoader();
          }
          final leaves = snap.data ?? const <LeaveModel>[];
          if (leaves.isEmpty) {
            return EmptyState(
              icon: Icons.beach_access_rounded,
              title: 'No leave requests yet',
              subtitle: 'Request time off and track its status here.',
              action: AppButton(
                label: 'Request leave',
                expand: false,
                onPressed: _request,
              ),
            );
          }

          final year = AttendanceClock.now().year;
          final workingDays =
              prov.company?.workingDays ?? const [1, 2, 3, 4, 5, 6];
          final shown = _filter == 'all'
              ? leaves
              : leaves.where((l) => l.status == _filter).toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.xs,
              AppSpacing.lg,
              AppSpacing.xxl,
            ),
            children: [
              Row(
                children: [
                  for (final t in quotaLeaveTypes) ...[
                    if (t != quotaLeaveTypes.first)
                      const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: _Balance(
                        label: StatusBadge.humanise(t),
                        quota: leaveQuota(prov.company, t)!,
                        used: leaveUsed(leaves, t, year, workingDays),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              AppSegmented<String>(
                segments: const {
                  'all': 'All',
                  'pending': 'Pending',
                  'approved': 'Approved',
                  'rejected': 'Rejected',
                },
                selected: _filter,
                onChanged: (v) => setState(() => _filter = v),
              ),
              const SizedBox(height: AppSpacing.md),
              if (shown.isEmpty)
                const AppCard(child: Text('Nothing here.'))
              else
                AppGroup(
                  children: [
                    for (final l in shown)
                      _LeaveRow(
                        leave: l,
                        days: leaveDaysOf(l, workingDays),
                        approver: prov.company?.adminName,
                      ),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Days left of a yearly allowance, with a bar.
class _Balance extends StatelessWidget {
  const _Balance({
    required this.label,
    required this.quota,
    required this.used,
  });

  final String label;
  final int quota;
  final double used;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final left = (quota - used).clamp(0, quota).toDouble();
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      radius: AppRadius.md,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(color: colors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 2),
          Text.rich(
            TextSpan(
              text: fmtDays(left),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              children: [
                TextSpan(
                  text: ' / $quota',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: colors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: quota == 0 ? 0 : left / quota,
              minHeight: 4,
              color: colors.brand,
              backgroundColor: colors.surfaceMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _LeaveRow extends StatelessWidget {
  const _LeaveRow({required this.leave, required this.days, this.approver});

  final LeaveModel leave;
  final double days;
  final String? approver;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final d = DateFormat('d MMM');
    final single = leave.durationDays == 1;
    final range = single
        ? d.format(leave.startDate)
        : '${d.format(leave.startDate)} – ${d.format(leave.endDate)}';
    final length = switch (leave.dayPart) {
      'first_half' => 'First half',
      'second_half' => 'Second half',
      _ => '${fmtDays(days)} ${days == 1 ? 'day' : 'days'}',
    };
    final note = (leave.adminNote ?? '').trim();
    final who = (approver ?? '').trim().split(' ').first;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$range · ${StatusBadge.humanise(leave.type)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  leave.reason.isEmpty ? length : '$length · ${leave.reason}',
                  style: TextStyle(color: colors.textSecondary, fontSize: 13),
                ),
                if (note.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    who.isEmpty ? '“$note”' : '$who: “$note”',
                    style: TextStyle(color: colors.textPrimary, fontSize: 13),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          StatusBadge(status: leave.status),
        ],
      ),
    );
  }
}
