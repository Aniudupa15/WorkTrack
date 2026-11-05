import 'package:flutter/material.dart';

import 'package:attendance_app/core/billing/entitlements.dart';
import 'package:attendance_app/features/billing/paywall.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:attendance_app/core/di/injection.dart';
import 'package:attendance_app/core/theme/app_colors.dart';
import 'package:attendance_app/core/theme/app_spacing.dart';
import 'package:attendance_app/core/widgets/app_card.dart';
import 'package:attendance_app/core/widgets/app_chip.dart';
import 'package:attendance_app/core/widgets/app_loader.dart';
import 'package:attendance_app/core/widgets/app_search_field.dart';
import 'package:attendance_app/core/widgets/avatar.dart';
import 'package:attendance_app/core/widgets/empty_state.dart';
import 'package:attendance_app/core/widgets/status_badge.dart';
import 'package:attendance_app/core/utils/attendance_clock.dart';
import 'package:attendance_app/core/widgets/entity_tile.dart';
import 'package:attendance_app/data/models/attendance_model.dart';
import 'package:attendance_app/data/models/leave_model.dart';
import 'package:attendance_app/data/models/user_model.dart';
import 'package:attendance_app/domain/repositories/employee_repository.dart';
import 'package:attendance_app/domain/repositories/leave_repository.dart';
import 'package:attendance_app/features/shared/leave_balance.dart';
import 'package:attendance_app/features/shared/today_status.dart';
import 'package:attendance_app/data/models/location_model.dart';
import 'package:attendance_app/data/datasources/storage_service.dart';
import 'package:attendance_app/domain/repositories/attendance_repository.dart';
import 'package:attendance_app/domain/repositories/location_repository.dart';
import 'package:attendance_app/features/shared/user_provider.dart';

class AttendanceLogsScreen extends StatefulWidget {
  const AttendanceLogsScreen({super.key});

  @override
  State<AttendanceLogsScreen> createState() => _AttendanceLogsScreenState();
}

class _AttendanceLogsScreenState extends State<AttendanceLogsScreen> {
  final _attendance = sl<AttendanceRepository>();

  /// Null shows every day (newest first); defaults to today.
  DateTime? _selectedDate = AttendanceClock.now();
  String _searchQuery = '';
  String _filter = 'all'; // all | present | late | absent

  /// Oldest day a Free company may see, or null.
  String? get _since => Entitlements.of(
    Provider.of<UserProvider>(context, listen: false).company,
  ).historySince;
  String? _site;
  late final String _companyId =
      Provider.of<UserProvider>(context, listen: false).company?.id ?? '';
  late final Stream<List<LocationModel>> _sites = sl<LocationRepository>()
      .watchLocations(_companyId);
  late final Stream<List<UserModel>> _people = sl<EmployeeRepository>()
      .watchEmployees(_companyId);
  late final Stream<List<LeaveModel>> _leaves = sl<LeaveRepository>()
      .watchAllLeaves(_companyId);

  Future<void> _pickDate() async {
    final now = AttendanceClock.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: _since == null ? DateTime(2020) : DateTime.parse(_since!),
      lastDate: now,
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  String get _dateLabel {
    final d = _selectedDate;
    if (d == null) return 'All days';
    final day = DateFormat('yyyy-MM-dd').format(d);
    final pretty = DateFormat('d MMM').format(d);
    return day == AttendanceClock.today() ? 'Today, $pretty' : pretty;
  }

  Widget _dropdown(String label, VoidCallback onTap) {
    final colors = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            Icon(
              Icons.expand_more_rounded,
              size: 20,
              color: colors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickSite(List<LocationModel> sites) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('All locations'),
              trailing: _site == null ? const Icon(Icons.check) : null,
              onTap: () => Navigator.pop(sheet, ''),
            ),
            for (final s in sites)
              ListTile(
                title: Text(s.name),
                trailing: _site == s.id ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(sheet, s.id),
              ),
          ],
        ),
      ),
    );
    if (picked != null) setState(() => _site = picked.isEmpty ? null : picked);
  }

  @override
  Widget build(BuildContext context) {
    final dateFilter = _selectedDate != null
        ? DateFormat('yyyy-MM-dd').format(_selectedDate!)
        : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance logs'),
        actions: [
          if (_selectedDate != null)
            TextButton(
              onPressed: () => setState(() => _selectedDate = null),
              child: const Text('All days'),
            ),
        ],
      ),
      body: StreamBuilder<List<LocationModel>>(
        stream: _sites,
        builder: (context, siteSnap) {
          final sites = siteSnap.data ?? const <LocationModel>[];
          final siteName = sites
              .where((s) => s.id == _site)
              .map((s) => s.name)
              .firstOrNull;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.lg,
                  0,
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: _dropdown(_dateLabel, _pickDate)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _dropdown(
                            siteName ?? 'All locations',
                            () => _pickSite(sites),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    AppSearchField(
                      hint: 'Search by employee name',
                      onChanged: (v) =>
                          setState(() => _searchQuery = v.toLowerCase()),
                    ),
                  ],
                ),
              ),
              if (_since != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.sm,
                    AppSpacing.lg,
                    0,
                  ),
                  child: GestureDetector(
                    onTap: () => showPaywall(context, PaywallReason.history),
                    child: Text(
                      'Showing the last ${Pricing.freeHistoryDays} days on the '
                      'Free plan · Upgrade for full history',
                      style: TextStyle(
                        color: context.colors.brandStrong,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              Expanded(child: _list(dateFilter)),
            ],
          );
        },
      ),
    );
  }

  Widget _list(String? dateFilter) {
    return StreamBuilder<List<UserModel>>(
      stream: _people,
      builder: (context, peopleSnap) => StreamBuilder<List<LeaveModel>>(
        stream: _leaves,
        builder: (context, leaveSnap) => StreamBuilder<List<AttendanceModel>>(
          stream: _attendance.watchAllLogs(
            _companyId,
            dateFilter: dateFilter,
            since: _since,
          ),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const AppLoader();
            }
            final company = Provider.of<UserProvider>(context).company;
            var logs = snapshot.data ?? [];
            if (_site != null) {
              logs = logs.where((l) => l.locationId == _site).toList();
            }

            // On a single day, people with no punch (and no leave) count as
            // absent: today once their start time plus the grace has passed,
            // earlier days when the day was a working day.
            var absent = <UserModel>[];
            if (dateFilter != null) {
              final punched = {for (final l in logs) l.employeeId};
              final onLeave = {
                for (final l in leaveSnap.data ?? const <LeaveModel>[])
                  if (onLeaveOn(l, dateFilter)) l.employeeId,
              };
              final isToday = dateFilter == AttendanceClock.today();
              final weekday = DateTime.parse(dateFilter).weekday;
              final workDay =
                  (company?.workingDays.contains(weekday) ?? true) &&
                  holidayOn(company, dateFilter) == null;
              bool missing(UserModel e) => isToday
                  ? todayStatus(
                          e,
                          null,
                          onLeave: false,
                          company: company,
                        ).status ==
                        'absent'
                  : workDay;
              absent = [
                for (final e in peopleSnap.data ?? const <UserModel>[])
                  if (e.status == 'active' &&
                      !punched.contains(e.id) &&
                      !onLeave.contains(e.id) &&
                      (_site == null || e.locationIds.contains(_site)) &&
                      missing(e))
                    e,
              ];
            }

            bool match(String name) =>
                _searchQuery.isEmpty ||
                name.toLowerCase().contains(_searchQuery);
            logs = logs.where((l) => match(l.employeeName)).toList();
            absent = absent.where((e) => match(e.name)).toList();

            final late = logs.where((l) => l.isLate).length;
            final present = logs.where((l) => l.checkIn != null).length - late;
            final shownLogs = switch (_filter) {
              'present' =>
                logs.where((l) => l.checkIn != null && !l.isLate).toList(),
              'late' => logs.where((l) => l.isLate).toList(),
              'absent' => const <AttendanceModel>[],
              _ => logs,
            };
            final shownAbsent = _filter == 'all' || _filter == 'absent'
                ? absent
                : const <UserModel>[];

            AppChip chip(String key, String label, int n) => AppChip(
              label: label,
              count: n,
              selected: _filter == key,
              onTap: () => setState(() => _filter = key),
            );

            return ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                40,
              ),
              children: [
                AppChipBar(
                  padding: EdgeInsets.zero,
                  children: [
                    chip('all', 'All', logs.length + absent.length),
                    chip('present', 'Present', present),
                    chip('late', 'Late', late),
                    if (dateFilter != null)
                      chip('absent', 'Absent', absent.length),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                if (shownLogs.isEmpty && shownAbsent.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: EmptyState(
                      icon: Icons.event_busy_rounded,
                      title: 'No records found',
                      subtitle: 'Try a different day, name or filter.',
                    ),
                  ),
                for (final log in shownLogs) ...[
                  _LogCard(log: log, showDate: dateFilter == null),
                  const SizedBox(height: AppSpacing.sm),
                ],
                if (shownAbsent.isNotEmpty)
                  AppGroup(
                    children: [
                      for (final e in shownAbsent)
                        EntityTile(
                          inGroup: true,
                          leading: Avatar(name: e.name, imageUrl: e.avatarUrl),
                          title: e.name,
                          subtitle: 'No punch',
                          trailing: const StatusBadge(status: 'absent'),
                        ),
                    ],
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _LogCard extends StatelessWidget {
  const _LogCard({required this.log, this.showDate = false});

  final AttendanceModel log;
  final bool showDate;

  String get _summary {
    final parts = [
      if (showDate) DateFormat('d MMM').format(DateTime.parse(log.date)),
      if (log.checkIn != null) DateFormat('h:mm a').format(log.checkIn!),
      ?log.locationName,
      if (log.selfieStoragePath != null) 'selfie ✓',
    ];
    return parts.isEmpty ? log.date : parts.join(' · ');
  }

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
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
          subtitle: Text(
            _summary,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          trailing: StatusBadge(status: log.isLate ? 'late' : log.status),
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
                    'Check-in',
                    log.checkIn != null
                        ? DateFormat('h:mm a').format(log.checkIn!)
                        : '--:--',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _row(
                    context,
                    Icons.logout_rounded,
                    'Check-out',
                    log.checkOut != null
                        ? DateFormat('h:mm a').format(log.checkOut!)
                        : '--:--',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (log.locationName != null) ...[
                    _row(
                      context,
                      Icons.location_on_outlined,
                      'Location',
                      log.locationName!,
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  _row(
                    context,
                    Icons.timelapse,
                    'Duration',
                    log.workDurationFormatted,
                  ),
                  if (log.selfieStoragePath != null &&
                      Entitlements.of(
                        Provider.of<UserProvider>(context).company,
                      ).hasBusiness) ...[
                    const SizedBox(height: AppSpacing.md),
                    _Selfie(path: log.selfieStoragePath!),
                  ],
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

/// The punch-in selfie: a thumbnail that opens full screen. Download URLs
/// come from Storage, where only the admin and the employee may read it.
class _Selfie extends StatefulWidget {
  const _Selfie({required this.path});

  final String path;

  @override
  State<_Selfie> createState() => _SelfieState();
}

class _SelfieState extends State<_Selfie> {
  late final Future<String> _url = sl<StorageService>().getDownloadUrl(
    widget.path,
  );

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return FutureBuilder<String>(
      future: _url,
      builder: (context, snap) {
        final url = snap.data;
        return Row(
          children: [
            Icon(
              Icons.photo_camera_outlined,
              size: 16,
              color: colors.textTertiary,
            ),
            const SizedBox(width: AppSpacing.md),
            Text('Selfie', style: Theme.of(context).textTheme.bodyMedium),
            const Spacer(),
            GestureDetector(
              onTap: url == null
                  ? null
                  : () => showDialog<void>(
                      context: context,
                      builder: (_) => Dialog(
                        clipBehavior: Clip.antiAlias,
                        child: Image.network(url, fit: BoxFit.contain),
                      ),
                    ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: url == null
                      ? ColoredBox(
                          color: colors.surfaceMuted,
                          child: snap.hasError
                              ? Icon(
                                  Icons.broken_image_outlined,
                                  color: colors.textTertiary,
                                )
                              : null,
                        )
                      : Image.network(url, fit: BoxFit.cover),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
