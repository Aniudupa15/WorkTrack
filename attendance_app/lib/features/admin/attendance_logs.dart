import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:attendance_app/core/di/injection.dart';
import 'package:attendance_app/core/theme/app_colors.dart';
import 'package:attendance_app/core/theme/app_spacing.dart';
import 'package:attendance_app/core/widgets/app_card.dart';
import 'package:attendance_app/core/widgets/app_loader.dart';
import 'package:attendance_app/core/widgets/app_search_field.dart';
import 'package:attendance_app/core/widgets/avatar.dart';
import 'package:attendance_app/core/widgets/empty_state.dart';
import 'package:attendance_app/core/widgets/status_badge.dart';
import 'package:attendance_app/data/models/attendance_model.dart';
import 'package:attendance_app/domain/repositories/attendance_repository.dart';
import 'package:attendance_app/features/shared/user_provider.dart';

class AttendanceLogsScreen extends StatefulWidget {
  const AttendanceLogsScreen({super.key});

  @override
  State<AttendanceLogsScreen> createState() => _AttendanceLogsScreenState();
}

class _AttendanceLogsScreenState extends State<AttendanceLogsScreen> {
  final _attendance = sl<AttendanceRepository>();
  DateTime? _selectedDate;
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final companyId =
        Provider.of<UserProvider>(context, listen: false).company?.id ?? '';
    final dateFilter = _selectedDate != null
        ? DateFormat('yyyy-MM-dd').format(_selectedDate!)
        : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance Logs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month_rounded),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate ?? DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (picked != null) setState(() => _selectedDate = picked);
            },
          ),
          if (_selectedDate != null)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () => setState(() => _selectedDate = null),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.md,
            ),
            child: AppSearchField(
              hint: 'Search by employee name',
              onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
            ),
          ),
          if (_selectedDate != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Chip(
                label: Text(DateFormat('MMMM dd, yyyy').format(_selectedDate!)),
                onDeleted: () => setState(() => _selectedDate = null),
              ),
            ),
          Expanded(
            child: StreamBuilder<List<AttendanceModel>>(
              stream: _attendance.watchAllLogs(
                companyId,
                dateFilter: dateFilter,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const AppLoader();
                }
                var logs = snapshot.data ?? [];

                if (_searchQuery.isNotEmpty) {
                  logs = logs
                      .where(
                        (log) =>
                            log.employeeName.toLowerCase().contains(
                              _searchQuery,
                            ) ||
                            log.employeeId.toLowerCase().contains(_searchQuery),
                      )
                      .toList();
                }

                if (logs.isEmpty) {
                  return const EmptyState(
                    icon: Icons.event_busy_rounded,
                    title: 'No records found',
                    subtitle: 'Try a different name or clear the date filter.',
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl,
                    AppSpacing.sm,
                    AppSpacing.xl,
                    40,
                  ),
                  itemCount: logs.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.md),
                  itemBuilder: (context, index) => _LogCard(log: logs[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LogCard extends StatelessWidget {
  const _LogCard({required this.log});

  final AttendanceModel log;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AppCard(
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          shape: const RoundedRectangleBorder(side: BorderSide.none),
          tilePadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          leading: Avatar(
            name: log.employeeName.isNotEmpty
                ? log.employeeName
                : log.employeeId,
            size: 40,
          ),
          title: Text(
            log.employeeName.isNotEmpty
                ? log.employeeName
                : log.employeeId.substring(0, 8),
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          subtitle: Text(
            log.date,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          trailing: StatusBadge(status: log.status),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                0,
                AppSpacing.xl,
                AppSpacing.xl,
              ),
              child: Column(
                children: [
                  Divider(color: colors.border),
                  const SizedBox(height: AppSpacing.md),
                  _row(
                    context,
                    Icons.login_rounded,
                    'Check In',
                    log.checkIn != null
                        ? DateFormat('hh:mm a').format(log.checkIn!)
                        : '--:--',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _row(
                    context,
                    Icons.logout_rounded,
                    'Check Out',
                    log.checkOut != null
                        ? DateFormat('hh:mm a').format(log.checkOut!)
                        : '--:--',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _row(
                    context,
                    Icons.timelapse,
                    'Duration',
                    log.workDurationFormatted,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, IconData icon, String label, String value) {
    final colors = context.colors;
    return Row(
      children: [
        Icon(icon, size: 16, color: colors.textTertiary),
        const SizedBox(width: AppSpacing.md),
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        const Spacer(),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }
}
