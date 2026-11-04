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
import 'package:attendance_app/data/models/attendance_model.dart';
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
  DateTime? _selectedDate;
  String _searchQuery = '';

  /// Oldest day a Free company may see, or null.
  String? get _since => Entitlements.of(
    Provider.of<UserProvider>(context, listen: false).company,
  ).historySince;
  String? _site;
  late final Stream<List<LocationModel>> _sites = sl<LocationRepository>()
      .watchLocations(
        Provider.of<UserProvider>(context, listen: false).company?.id ?? '',
      );

  @override
  Widget build(BuildContext context) {
    final companyId =
        Provider.of<UserProvider>(context, listen: false).company?.id ?? '';
    final dateFilter = _selectedDate != null
        ? DateFormat('yyyy-MM-dd').format(_selectedDate!)
        : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance logs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month_rounded),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate ?? DateTime.now(),
                firstDate: _since == null
                    ? DateTime(2020)
                    : DateTime.parse(_since!),
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
          if (_since != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                0,
                AppSpacing.xl,
                AppSpacing.md,
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
          StreamBuilder<List<LocationModel>>(
            stream: _sites,
            builder: (context, snap) {
              final sites = snap.data ?? const <LocationModel>[];
              if (sites.length < 2) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: AppChipBar(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl,
                  ),
                  children: [
                    AppChip(
                      label: 'All locations',
                      icon: Icons.location_on_outlined,
                      selected: _site == null,
                      onTap: () => setState(() => _site = null),
                    ),
                    for (final s in sites)
                      AppChip(
                        label: s.name,
                        selected: _site == s.id,
                        onTap: () => setState(() => _site = s.id),
                      ),
                  ],
                ),
              );
            },
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
                since: _since,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const AppLoader();
                }
                var logs = snapshot.data ?? [];
                if (_site != null) {
                  logs = logs.where((l) => l.locationId == _site).toList();
                }

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
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
          subtitle: Text(
            log.locationName == null
                ? log.date
                : '${log.date} · ${log.locationName}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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
