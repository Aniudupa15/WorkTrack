import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:attendance_app/core/di/injection.dart';
import 'package:attendance_app/core/theme/app_colors.dart';
import 'package:attendance_app/core/theme/app_spacing.dart';
import 'package:attendance_app/core/utils/attendance_clock.dart';
import 'package:attendance_app/core/widgets/app_button.dart';
import 'package:attendance_app/core/widgets/app_card.dart';
import 'package:attendance_app/core/widgets/app_loader.dart';
import 'package:attendance_app/core/widgets/avatar.dart';
import 'package:attendance_app/core/widgets/entity_tile.dart';
import 'package:attendance_app/core/widgets/status_badge.dart';
import 'package:attendance_app/data/models/attendance_model.dart';
import 'package:attendance_app/data/models/leave_model.dart';
import 'package:attendance_app/data/models/location_model.dart';
import 'package:attendance_app/data/models/user_model.dart';
import 'package:attendance_app/domain/repositories/attendance_repository.dart';
import 'package:attendance_app/domain/repositories/employee_repository.dart';
import 'package:attendance_app/domain/repositories/leave_repository.dart';
import 'package:attendance_app/domain/repositories/location_repository.dart';
import 'package:attendance_app/features/admin/add_edit_employee.dart';
import 'package:attendance_app/features/admin/assign_sites_sheet.dart';
import 'package:attendance_app/features/shared/leave_balance.dart';
import 'package:attendance_app/features/shared/today_status.dart';
import 'package:attendance_app/features/shared/user_provider.dart';

/// One person, from the admin's side: today's status, how to reach them,
/// where they may punch, their shift, and this month at a glance.
class EmployeeDetailScreen extends StatefulWidget {
  const EmployeeDetailScreen({super.key, required this.employee});

  final UserModel employee;

  @override
  State<EmployeeDetailScreen> createState() => _EmployeeDetailScreenState();
}

class _EmployeeDetailScreenState extends State<EmployeeDetailScreen> {
  late final _companyId =
      Provider.of<UserProvider>(context, listen: false).company?.id ?? '';
  late final Stream<List<UserModel>> _people = sl<EmployeeRepository>()
      .watchEmployees(_companyId);
  late final Stream<List<LocationModel>> _sites = sl<LocationRepository>()
      .watchLocations(_companyId);
  late final Stream<List<AttendanceModel>> _history = sl<AttendanceRepository>()
      .watchEmployeeHistory(_companyId, widget.employee.id);
  late final Stream<List<LeaveModel>> _leaves = sl<LeaveRepository>()
      .watchEmployeeLeaves(_companyId, widget.employee.id);
  bool _busy = false;

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  void _edit(UserModel e) {
    final company = Provider.of<UserProvider>(context, listen: false).company;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddEditEmployee(
          employee: e,
          companyId: _companyId,
          defaultRadius: company?.defaultRadius ?? 100,
          defaultShiftStart: company?.defaultShiftStart ?? '09:00',
          defaultShiftEnd: company?.defaultShiftEnd ?? '18:00',
        ),
      ),
    );
  }

  Future<void> _editSites(UserModel e, List<LocationModel> sites) async {
    final result = await showAssignSitesSheet(
      context,
      sites: sites,
      selected: e.locationIds,
      primaryId: e.primaryLocationId,
    );
    if (result == null) return;
    try {
      await sl<LocationRepository>().assignLocations(
        _companyId,
        e.id,
        locationIds: result.ids,
        primary: sites.where((s) => s.id == result.primaryId).firstOrNull,
      );
    } catch (_) {
      _snack('Couldn’t update locations');
    }
  }

  Future<void> _setActive(UserModel e, bool active) async {
    if (!active) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (d) => AlertDialog(
          title: Text('Deactivate ${e.name}?'),
          content: const Text(
            'They can no longer punch in, and they stop counting towards '
            'your plan. Their history is kept and you can reactivate them '
            'any time.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(d, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(d, true),
              child: Text(
                'Deactivate',
                style: TextStyle(color: context.colors.danger),
              ),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    setState(() => _busy = true);
    try {
      await sl<EmployeeRepository>().setStatus(
        _companyId,
        e.id,
        active ? 'active' : 'inactive',
      );
    } catch (_) {
      _snack('Couldn’t update ${e.name}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<UserModel>>(
      stream: _people,
      builder: (context, peopleSnap) {
        final people = peopleSnap.data ?? const <UserModel>[];
        final e =
            people.where((p) => p.id == widget.employee.id).firstOrNull ??
            widget.employee;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Employee'),
            actions: [
              PopupMenuButton<String>(
                tooltip: 'More options',
                onSelected: (v) {
                  if (v == 'edit') _edit(e);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit details')),
                ],
              ),
            ],
          ),
          body: StreamBuilder<List<LocationModel>>(
            stream: _sites,
            builder: (context, siteSnap) =>
                StreamBuilder<List<AttendanceModel>>(
                  stream: _history,
                  builder: (context, histSnap) =>
                      StreamBuilder<List<LeaveModel>>(
                        stream: _leaves,
                        builder: (context, leaveSnap) {
                          if (histSnap.connectionState ==
                              ConnectionState.waiting) {
                            return const AppLoader();
                          }
                          return _body(
                            e,
                            people,
                            siteSnap.data ?? const [],
                            histSnap.data ?? const [],
                            leaveSnap.data ?? const [],
                          );
                        },
                      ),
                ),
          ),
        );
      },
    );
  }

  Widget _body(
    UserModel e,
    List<UserModel> people,
    List<LocationModel> sites,
    List<AttendanceModel> history,
    List<LeaveModel> leaves,
  ) {
    final colors = context.colors;
    final company = Provider.of<UserProvider>(context).company;
    final day = AttendanceClock.today();
    final todayLog = history.where((h) => h.date == day).firstOrNull;
    final today = todayStatus(
      e,
      todayLog,
      onLeave: leaves.any((l) => onLeaveOn(l, day)),
      company: company,
    );
    final time = DateFormat('h:mm a');
    final todayLabel = switch (today.label) {
      'In' => 'In since ${time.format(todayLog!.checkIn!)}',
      'Late' => 'Late · in at ${time.format(todayLog!.checkIn!)}',
      'Out' => 'Out at ${time.format(todayLog!.checkOut!)}',
      'Leave' => 'On leave today',
      'Not in' => 'Not in yet',
      'Off' => 'Day off',
      _ => today.label,
    };

    final subtitle = [
      e.department ?? e.position,
      e.employeeNumber,
    ].whereType<String>().where((s) => s.isNotEmpty).join(' · ');

    // This month at a glance.
    final month = day.substring(0, 7);
    final monthLogs = history.where((h) => h.date.startsWith(month));
    final late = monthLogs.where((h) => h.isLate).length;
    final present = monthLogs.where((h) => h.checkIn != null).length - late;
    final leaveDays = {
      for (
        var d = DateTime.parse('$month-01');
        d.month == DateTime.parse('$month-01').month &&
            !d.isAfter(DateTime.parse(day));
        d = d.add(const Duration(days: 1))
      )
        if (leaves.any((l) => onLeaveOn(l, DateFormat('yyyy-MM-dd').format(d))))
          d,
    }.length;
    final workedOrLeave = {...monthLogs.map((h) => h.date)};
    var absent = 0;
    for (
      var d = DateTime.parse('$month-01');
      d.isBefore(DateTime.parse(day));
      d = d.add(const Duration(days: 1))
    ) {
      final key = DateFormat('yyyy-MM-dd').format(d);
      if ((company?.workingDays.contains(d.weekday) ?? true) &&
          holidayOn(company, key) == null &&
          !workedOrLeave.contains(key) &&
          !leaves.any((l) => onLeaveOn(l, key)) &&
          (e.joinedAt == null || !d.isBefore(_dateOnly(e.joinedAt!)))) {
        absent++;
      }
    }
    if (today.status == 'absent') absent++;

    final mySites = [
      for (final id in e.locationIds)
        ?sites.where((s) => s.id == id).firstOrNull,
    ];
    int headcount(String siteId) =>
        people.where((p) => p.locationIds.contains(siteId)).length;
    final days = company?.workingDays ?? const [1, 2, 3, 4, 5, 6];
    final custom =
        e.shift != null &&
        (e.shiftStart != (company?.defaultShiftStart ?? '09:00') ||
            e.shiftEnd != (company?.defaultShiftEnd ?? '18:00'));

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.xxl,
      ),
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Avatar(name: e.name, imageUrl: e.avatarUrl, size: 64),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          e.name,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        if (subtitle.isNotEmpty)
                          Text(
                            subtitle,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        const SizedBox(height: 6),
                        StatusBadge(status: today.status, label: todayLabel),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: 'Call',
                      icon: Icons.call_outlined,
                      size: AppButtonSize.small,
                      variant: AppButtonVariant.secondary,
                      onPressed: e.phone == null
                          ? null
                          : () => launchUrl(Uri.parse('tel:${e.phone}')),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: AppButton(
                      label: 'Attendance',
                      icon: Icons.event_note_outlined,
                      size: AppButtonSize.small,
                      variant: AppButtonVariant.secondary,
                      onPressed: () => _showHistory(e, history),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Work locations',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
            ),
            TextButton(
              onPressed: sites.isEmpty ? null : () => _editSites(e, sites),
              child: const Text('Edit'),
            ),
          ],
        ),
        if (mySites.isEmpty)
          AppCard(
            child: Text(
              'No location assigned — they can’t punch in yet.',
              style: TextStyle(color: colors.danger),
            ),
          )
        else
          AppGroup(
            children: [
              for (final s in mySites)
                EntityTile(
                  inGroup: true,
                  leading: IconChip(
                    icon: s.isMain
                        ? Icons.apartment_rounded
                        : Icons.warehouse_outlined,
                  ),
                  title: s.name,
                  subtitle:
                      '${s.radius.round()} m radius · '
                      '${headcount(s.id)} people',
                  trailing: s.id == (e.primaryLocationId ?? e.locationIds.first)
                      ? const StatusBadge(
                          status: 'brand',
                          label: 'Primary',
                          dot: false,
                        )
                      : null,
                ),
            ],
          ),
        const SizedBox(height: AppSpacing.lg),
        _section('Shift'),
        AppGroup(
          children: [
            EntityTile(
              inGroup: true,
              title:
                  '${AttendanceClock.formatShiftTime(e.shiftStart)} – '
                  '${AttendanceClock.formatShiftTime(e.shiftEnd)}',
              subtitle:
                  '${_dayRange(days)} · '
                  '${custom ? 'their own shift' : 'company default'}',
              chevron: true,
              onTap: () => _edit(e),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        _section(DateFormat('MMMM').format(DateTime.parse('$month-01'))),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            StatusBadge(status: 'present', label: '$present present'),
            StatusBadge(status: 'late', label: '$late late'),
            StatusBadge(status: 'leave', label: '$leaveDays leave'),
            StatusBadge(status: 'absent', label: '$absent absent'),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        if (e.status == 'active')
          AppButton(
            label: 'Deactivate employee',
            variant: AppButtonVariant.danger,
            loading: _busy,
            onPressed: _busy ? null : () => _setActive(e, false),
          )
        else
          AppButton(
            label: 'Reactivate employee',
            variant: AppButtonVariant.secondary,
            loading: _busy,
            onPressed: _busy ? null : () => _setActive(e, true),
          ),
      ],
    );
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// "Mon–Sat", or "Mon, Wed, Fri" when the days aren't a run.
  static String _dayRange(List<int> days) {
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final sorted = [...days]..sort();
    if (sorted.isEmpty) return 'No working days';
    final run =
        sorted.last - sorted.first == sorted.length - 1 && sorted.length > 2;
    return run
        ? '${names[sorted.first - 1]}–${names[sorted.last - 1]}'
        : sorted.map((d) => names[d - 1]).join(', ');
  }

  Widget _section(String title) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm, left: 4),
    child: Text(
      title.toUpperCase(),
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.6,
        color: context.colors.textTertiary,
      ),
    ),
  );

  void _showHistory(UserModel e, List<AttendanceModel> history) {
    final time = DateFormat('h:mm a');
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            Text(
              '${e.name.split(' ').first}’s attendance',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            if (history.isEmpty) const Text('No punches yet.'),
            AppGroup(
              children: [
                for (final h in history.take(60))
                  EntityTile(
                    inGroup: true,
                    title: DateFormat(
                      'EEE, d MMM',
                    ).format(DateTime.parse(h.date)),
                    subtitle: [
                      if (h.checkIn != null) time.format(h.checkIn!),
                      if (h.checkOut != null) time.format(h.checkOut!),
                    ].join(' – ').ifEmpty(h.locationName ?? ''),
                    trailing: StatusBadge(status: h.isLate ? 'late' : h.status),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

extension on String {
  String ifEmpty(String other) => isEmpty ? other : this;
}
