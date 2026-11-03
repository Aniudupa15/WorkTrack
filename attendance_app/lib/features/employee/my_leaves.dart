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
import 'package:attendance_app/core/widgets/entity_tile.dart';
import 'package:attendance_app/core/widgets/metric_tile.dart';
import 'package:attendance_app/core/widgets/status_badge.dart';
import 'package:attendance_app/data/models/leave_model.dart';
import 'package:attendance_app/domain/repositories/leave_repository.dart';
import 'package:attendance_app/features/employee/leave_request.dart';
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
    final colors = context.colors;
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
          int taken(String type) => leaves
              .where(
                (l) =>
                    l.type == type &&
                    l.status == 'approved' &&
                    l.startDate.year == year,
              )
              .fold(0, (sum, l) => sum + l.durationDays);
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
              Text(
                'Days taken in $year',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              MetricRow(
                tiles: [
                  MetricTile(
                    label: 'Casual',
                    value: '${taken('casual')}',
                    dotColor: colors.info,
                  ),
                  MetricTile(
                    label: 'Sick',
                    value: '${taken('sick')}',
                    dotColor: colors.info,
                  ),
                  MetricTile(
                    label: 'Earned',
                    value: '${taken('earned')}',
                    dotColor: colors.info,
                  ),
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
                  children: [for (final l in shown) _LeaveRow(leave: l)],
                ),
            ],
          );
        },
      ),
    );
  }
}

class _LeaveRow extends StatelessWidget {
  const _LeaveRow({required this.leave});

  final LeaveModel leave;

  @override
  Widget build(BuildContext context) {
    final d = DateFormat('d MMM');
    final range = leave.durationDays == 1
        ? d.format(leave.startDate)
        : '${d.format(leave.startDate)} – ${d.format(leave.endDate)}';
    final days =
        '${leave.durationDays} ${leave.durationDays == 1 ? 'day' : 'days'}';
    final note = (leave.adminNote ?? '').isNotEmpty
        ? '\nNote: ${leave.adminNote}'
        : '';
    return EntityTile(
      inGroup: true,
      title: '$range · ${StatusBadge.humanise(leave.type)}',
      subtitle: '$days · ${leave.reason}$note',
      trailing: StatusBadge(status: leave.status),
    );
  }
}
