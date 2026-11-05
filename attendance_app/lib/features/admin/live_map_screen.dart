import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import 'package:attendance_app/core/constants/app_constants.dart';
import 'package:attendance_app/core/di/injection.dart';
import 'package:attendance_app/core/theme/app_colors.dart';
import 'package:attendance_app/core/theme/app_spacing.dart';
import 'package:attendance_app/core/utils/attendance_clock.dart';
import 'package:attendance_app/core/widgets/app_card.dart';
import 'package:attendance_app/core/widgets/app_chip.dart';
import 'package:attendance_app/core/widgets/avatar.dart';
import 'package:attendance_app/core/widgets/entity_tile.dart';
import 'package:attendance_app/core/widgets/status_badge.dart';
import 'package:attendance_app/data/models/attendance_model.dart';
import 'package:attendance_app/data/models/location_model.dart';
import 'package:attendance_app/data/models/punch_attempt_model.dart';
import 'package:attendance_app/data/models/user_model.dart';
import 'package:attendance_app/domain/repositories/attendance_repository.dart';
import 'package:attendance_app/domain/repositories/employee_repository.dart';
import 'package:attendance_app/domain/repositories/location_repository.dart';
import 'package:attendance_app/features/admin/employee_detail_screen.dart';
import 'package:attendance_app/features/shared/user_provider.dart';

/// Today's punches on a map: each site's zone with how many are in, and a
/// pin where each person last punched. Not live tracking — the app never
/// reads location outside a punch.
class LiveMapScreen extends StatefulWidget {
  const LiveMapScreen({super.key});

  @override
  State<LiveMapScreen> createState() => _LiveMapScreenState();
}

class _LiveMapScreenState extends State<LiveMapScreen> {
  late final _companyId =
      Provider.of<UserProvider>(context, listen: false).company?.id ?? '';
  late final Stream<List<LocationModel>> _sites = sl<LocationRepository>()
      .watchLocations(_companyId);
  late final Stream<List<UserModel>> _people = sl<EmployeeRepository>()
      .watchEmployees(_companyId);
  late final Stream<List<AttendanceModel>> _today = sl<AttendanceRepository>()
      .watchAllLogs(_companyId, dateFilter: AttendanceClock.today());
  late final Stream<List<PunchAttempt>> _attempts = sl<AttendanceRepository>()
      .watchFailedAttempts(_companyId, AttendanceClock.today());
  final _map = MapController();
  String? _site;
  bool _mapReady = false;
  bool _framed = false;
  DateTime _updated = AttendanceClock.now();

  static LatLng? _fix(Map<String, dynamic>? loc) {
    final lat = (loc?['latitude'] as num?)?.toDouble();
    final lng = (loc?['longitude'] as num?)?.toDouble();
    return lat == null || lng == null ? null : LatLng(lat, lng);
  }

  void _focus(List<LocationModel> sites) {
    final shown = _site == null ? sites : sites.where((s) => s.id == _site);
    final points = [for (final s in shown) LatLng(s.latitude, s.longitude)];
    if (points.isEmpty) return;
    if (points.length == 1) {
      _map.move(points.first, 16);
    } else {
      _map.fitCamera(
        CameraFit.coordinates(
          coordinates: points,
          padding: const EdgeInsets.fromLTRB(96, 200, 96, 340),
        ),
      );
    }
  }

  /// Fits every site the first time both the map and the site list exist.
  void _frameOnce(List<LocationModel> sites) {
    if (_framed || !_mapReady || sites.isEmpty) return;
    _framed = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus(sites);
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<LocationModel>>(
      stream: _sites,
      builder: (context, siteSnap) => StreamBuilder<List<UserModel>>(
        stream: _people,
        builder: (context, peopleSnap) => StreamBuilder<List<AttendanceModel>>(
          stream: _today,
          builder: (context, logSnap) => StreamBuilder<List<PunchAttempt>>(
            stream: _attempts,
            builder: (context, attemptSnap) {
              if (logSnap.hasData) _updated = AttendanceClock.now();
              return _build(
                siteSnap.data ?? const [],
                peopleSnap.data ?? const [],
                logSnap.data ?? const [],
                attemptSnap.data ?? const [],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _build(
    List<LocationModel> sites,
    List<UserModel> people,
    List<AttendanceModel> logs,
    List<PunchAttempt> attempts,
  ) {
    final colors = context.colors;
    _frameOnce(sites);
    final byId = {for (final p in people) p.id: p};
    final visible = _site == null
        ? logs
        : logs.where((l) => l.locationId == _site).toList();
    final inNow = visible
        .where((l) => l.checkIn != null && l.checkOut == null)
        .toList();
    final out = visible.where((l) => l.checkOut != null).length;
    final late = inNow.where((l) => l.isLate).toList();
    final punchedIn = {
      for (final l in logs)
        if (l.checkIn != null) l.employeeId,
    };
    final failed = FailedTries.group(attempts)
        .where(
          (f) =>
              !punchedIn.contains(f.employeeId) &&
              (_site == null || f.closest.locationId == _site),
        )
        .toList();
    String metres(double m) =>
        m >= 1000 ? '${(m / 1000).toStringAsFixed(1)} km' : '${m.round()} m';
    int inAt(String siteId) => logs
        .where(
          (l) =>
              l.locationId == siteId && l.checkIn != null && l.checkOut == null,
        )
        .length;

    final shownSites = _site == null
        ? sites
        : sites.where((s) => s.id == _site).toList();
    final center = shownSites.isEmpty
        ? const LatLng(12.9716, 77.5946)
        : LatLng(shownSites.first.latitude, shownSites.first.longitude);

    Widget stat(int n, String label, Color dot, {Color? valueColor}) =>
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$n',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: valueColor,
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: dot,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      label,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter: center,
              initialZoom: 14,
              onMapReady: () {
                _mapReady = true;
                _frameOnce(sites);
              },
            ),
            children: [
              TileLayer(
                urlTemplate: AppConstants.osmTileUrl,
                userAgentPackageName: AppConstants.packageName,
              ),
              CircleLayer(
                circles: [
                  for (final s in shownSites)
                    CircleMarker(
                      point: LatLng(s.latitude, s.longitude),
                      useRadiusInMeter: true,
                      radius: s.radius,
                      color: colors.brand.withValues(alpha: 0.15),
                      borderColor: colors.brand,
                      borderStrokeWidth: 2,
                    ),
                ],
              ),
              MarkerLayer(
                markers: [
                  for (final l in inNow)
                    if (_fix(l.checkInLocation) case final p?)
                      Marker(
                        point: p,
                        width: 34,
                        height: 34,
                        child: Tooltip(
                          message: l.employeeName,
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: l.isLate
                                    ? colors.warning
                                    : colors.success,
                                width: 2,
                              ),
                            ),
                            child: Avatar(
                              name: l.employeeName,
                              imageUrl: byId[l.employeeId]?.avatarUrl,
                              size: 30,
                            ),
                          ),
                        ),
                      ),
                  for (final s in shownSites)
                    Marker(
                      point: LatLng(s.latitude, s.longitude),
                      width: 160,
                      height: 64,
                      // Label then icon, all above the point, so pins of people
                      // at the site stay visible.
                      alignment: Alignment.topCenter,
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: colors.surface,
                              borderRadius: BorderRadius.circular(999),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x22000000),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                            child: Text(
                              '${s.name} · ${inAt(s.id)} in',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: colors.brand,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: Icon(
                              s.isMain
                                  ? Icons.apartment_rounded
                                  : Icons.warehouse_outlined,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Material(
                        color: colors.surface,
                        shape: const CircleBorder(),
                        elevation: 2,
                        child: IconButton(
                          tooltip: 'Back',
                          icon: const Icon(Icons.arrow_back_rounded),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Material(
                        color: colors.surface,
                        elevation: 2,
                        borderRadius: BorderRadius.circular(999),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          child: Text(
                            'Live map',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (sites.length > 1) ...[
                    const SizedBox(height: 8),
                    AppChipBar(
                      padding: EdgeInsets.zero,
                      children: [
                        AppChip(
                          label: 'All',
                          count: sites.length,
                          selected: _site == null,
                          onTap: () {
                            setState(() => _site = null);
                            _focus(sites);
                          },
                        ),
                        for (final s in sites)
                          AppChip(
                            label: s.name,
                            selected: _site == s.id,
                            onTap: () {
                              setState(() => _site = s.id);
                              _focus(sites);
                            },
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          DraggableScrollableSheet(
            initialChildSize: 0.3,
            minChildSize: 0.16,
            maxChildSize: 0.75,
            builder: (context, controller) => Container(
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppRadius.xl),
                ),
                boxShadow: const [
                  BoxShadow(color: Color(0x22000000), blurRadius: 16),
                ],
              ),
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: colors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Right now',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      Text(
                        'Updated ${DateFormat('h:mm a').format(_updated)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      stat(inNow.length, 'Checked in', colors.success),
                      stat(out, 'Checked out', colors.textTertiary),
                      stat(
                        failed.length,
                        'Failed',
                        colors.danger,
                        valueColor: failed.isNotEmpty ? colors.danger : null,
                      ),
                    ],
                  ),
                  if (failed.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    AppGroup(
                      children: [
                        for (final f in failed)
                          EntityTile(
                            inGroup: true,
                            leading: Avatar(
                              name: f.employeeName,
                              imageUrl: byId[f.employeeId]?.avatarUrl,
                            ),
                            title: f.employeeName,
                            subtitle:
                                '${f.count} ${f.count == 1 ? 'try' : 'tries'} from '
                                '${metres(f.closest.distance)} outside '
                                '${f.closest.locationName ?? 'the zone'}',
                            trailing: const StatusBadge(
                              status: 'absent',
                              label: 'Check',
                            ),
                            onTap: byId[f.employeeId] == null
                                ? null
                                : () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => EmployeeDetailScreen(
                                        employee: byId[f.employeeId]!,
                                      ),
                                    ),
                                  ),
                          ),
                      ],
                    ),
                  ],
                  if (late.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    AppGroup(
                      children: [
                        for (final l in late)
                          EntityTile(
                            inGroup: true,
                            leading: Avatar(
                              name: l.employeeName,
                              imageUrl: byId[l.employeeId]?.avatarUrl,
                            ),
                            title: l.employeeName,
                            subtitle:
                                'In at ${DateFormat('h:mm a').format(l.checkIn!)}'
                                '${l.locationName == null ? '' : ' · ${l.locationName}'}',
                            trailing: const StatusBadge(status: 'late'),
                            onTap: byId[l.employeeId] == null
                                ? null
                                : () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => EmployeeDetailScreen(
                                        employee: byId[l.employeeId]!,
                                      ),
                                    ),
                                  ),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  Text(
                    'Shows where people last punched — not live tracking.',
                    style: TextStyle(fontSize: 12, color: colors.textTertiary),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
