import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import 'package:attendance_app/core/constants/app_constants.dart';
import 'package:attendance_app/core/di/injection.dart';
import 'package:attendance_app/core/error/app_exception.dart';
import 'package:attendance_app/core/theme/app_colors.dart';
import 'package:attendance_app/core/theme/app_spacing.dart';
import 'package:attendance_app/core/utils/attendance_clock.dart';
import 'package:attendance_app/core/widgets/app_button.dart';
import 'package:attendance_app/core/widgets/app_loader.dart';
import 'package:attendance_app/core/widgets/app_page.dart';
import 'package:attendance_app/data/datasources/analytics_service.dart';
import 'package:attendance_app/data/datasources/location_service.dart';
import 'package:attendance_app/data/models/attendance_model.dart';
import 'package:attendance_app/domain/repositories/attendance_repository.dart';
import 'package:attendance_app/features/employee/punch_success.dart';
import 'package:attendance_app/features/shared/user_provider.dart';

/// Live punch screen: the work zone on a map with a bottom sheet that shows
/// whether the employee is inside it, and the punch in / out action.
class MarkAttendanceScreen extends StatefulWidget {
  const MarkAttendanceScreen({super.key});
  @override
  State<MarkAttendanceScreen> createState() => _MarkAttendanceScreenState();
}

class _MarkAttendanceScreenState extends State<MarkAttendanceScreen> {
  final LocationService _locationService = sl<LocationService>();
  final AttendanceRepository _attendance = sl<AttendanceRepository>();
  final MapController _map = MapController();
  LatLng? _currentLocation;
  Position? _position;
  String? _locationError;
  bool _isLoading = true;
  bool _actionLoading = false;
  AttendanceModel? _todayAttendance;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final prov = Provider.of<UserProvider>(context, listen: false);
    if (prov.user != null && prov.company != null) {
      try {
        _todayAttendance = await _attendance.getTodayAttendance(
          prov.company!.id,
          prov.user!.id,
        );
      } catch (_) {
        // Shown as "not punched yet"; the punch itself re-validates server-side.
      }
    }
    await _updateCurrentLocation();
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _updateCurrentLocation() async {
    try {
      final pos = await _locationService.getCurrentLocation();
      if (pos != null && mounted) {
        setState(() {
          _position = pos;
          _locationError = null;
          _currentLocation = LatLng(pos.latitude, pos.longitude);
        });
      }
    } catch (e) {
      if (mounted) setState(() => _locationError = '$e');
    }
  }

  LatLng? get _workLoc {
    final user = Provider.of<UserProvider>(context, listen: false).user;
    if (user?.workLatitude == null || user?.workLongitude == null) return null;
    return LatLng(user!.workLatitude!, user.workLongitude!);
  }

  bool get _isNearby {
    final work = _workLoc;
    final user = Provider.of<UserProvider>(context, listen: false).user;
    if (_currentLocation == null || work == null || user == null) return false;
    return _locationService.isWithinRadius(
      _currentLocation!,
      work,
      user.workRadius,
    );
  }

  /// Straight-line distance in metres from the employee to the work location,
  /// or null when either point is unknown.
  double? get _distanceMeters {
    final work = _workLoc;
    if (_currentLocation == null || work == null) return null;
    return const Distance().as(LengthUnit.Meter, _currentLocation!, work);
  }

  String _fmtDistance(double m) =>
      m >= 1000 ? '${(m / 1000).toStringAsFixed(1)} km' : '${m.round()} m';

  /// Takes a fresh GPS fix and checks it is usable for a punch: assigned work
  /// location, not a mock location, accurate enough, and inside the zone.
  /// Returns the location payload, or null after showing why not.
  Future<Map<String, dynamic>?> _verifiedFix() async {
    if (_workLoc == null) {
      _showError(
        'No work location yet',
        'Your admin hasn’t assigned a work location to you yet.',
      );
      return null;
    }

    await _updateCurrentLocation();
    final pos = _position;
    if (!mounted) return null;
    if (pos == null) {
      _showError(
        'Location unavailable',
        'We couldn’t get your location. Check that location is turned on.',
      );
      return null;
    }
    if (pos.isMocked) {
      _showError(
        'Fake GPS detected',
        'Turn off any mock-location or GPS-spoofing app to punch in.',
      );
      return null;
    }
    if (pos.accuracy > AppConstants.maxLocationAccuracyMeters) {
      _showError(
        'Weak GPS signal',
        'Your location is only accurate to ${pos.accuracy.round()} m. '
            'Step near a window or into an open area and try again.',
      );
      return null;
    }
    // Outside the zone is shown in the sheet itself; nothing more to say.
    if (!_isNearby) return null;
    return {
      'latitude': pos.latitude,
      'longitude': pos.longitude,
      'accuracy': pos.accuracy,
    };
  }

  Future<void> _punch() async {
    final prov = Provider.of<UserProvider>(context, listen: false);
    final user = prov.user!;
    final company = prov.company!;
    final checkingOut = _todayAttendance?.checkIn != null;

    if (!checkingOut) {
      final shiftEnd = AttendanceClock.parseMinutes(user.shiftEnd);
      if (shiftEnd != null &&
          AttendanceClock.minutesOfDay(AttendanceClock.now()) >= shiftEnd) {
        _showError(
          'Shift is over',
          'Your shift ended at ${user.shiftEnd}. Punch-in is closed for today.',
        );
        return;
      }
    }

    setState(() => _actionLoading = true);
    try {
      final location = await _verifiedFix();
      if (location == null) return;

      var withSelfie = false;
      if (checkingOut) {
        await _attendance.checkOut(
          companyId: company.id,
          employeeId: user.id,
          location: location,
        );
        unawaited(sl<AnalyticsService>().logCheckOut(offline: false));
      } else {
        String? selfiePath;
        try {
          final photo = await ImagePicker().pickImage(
            source: ImageSource.camera,
            preferredCameraDevice: CameraDevice.front,
            maxWidth: 640,
          );
          if (photo != null) {
            selfiePath = await _attendance.uploadSelfie(
              company.id,
              user.id,
              File(photo.path),
            );
          }
        } catch (_) {
          // Camera unavailable or cancelled — punch without a selfie.
        }
        withSelfie = selfiePath != null;
        await _attendance.checkIn(
          companyId: company.id,
          employeeId: user.id,
          employeeName: user.name,
          shiftStart: user.shiftStart,
          location: location,
          selfieStoragePath: selfiePath,
        );
        unawaited(sl<AnalyticsService>().logCheckIn(offline: false));
      }

      final record = await _attendance.getTodayAttendance(company.id, user.id);
      if (!mounted || record == null) return;
      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PunchSuccessScreen(
            record: record,
            checkedOut: checkingOut,
            locationName: user.workAddress ?? 'Work location',
            distanceMeters: _distanceMeters,
            withSelfie: withSelfie,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        _showError(
          checkingOut ? 'Couldn’t punch out' : 'Couldn’t punch in',
          e is AppException ? e.message : 'Something went wrong. Try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  void _showError(String title, String message) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserProvider>(context).user;
    if (user == null || _isLoading) {
      return const Scaffold(body: AppLoader());
    }
    final colors = context.colors;
    final work = _workLoc;
    final inside = _isNearby;
    final zoneColor = _currentLocation == null || inside
        ? colors.brand
        : colors.danger;

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter:
                  work ?? _currentLocation ?? const LatLng(20.5937, 78.9629),
              initialZoom: work != null ? 16.5 : 5.0,
            ),
            children: [
              TileLayer(
                urlTemplate: AppConstants.osmTileUrl,
                userAgentPackageName: AppConstants.packageName,
              ),
              if (work != null)
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: work,
                      useRadiusInMeter: true,
                      radius: user.workRadius,
                      color: zoneColor.withValues(alpha: 0.12),
                      borderColor: zoneColor,
                      borderStrokeWidth: 2,
                    ),
                  ],
                ),
              if (work != null && _currentLocation != null && !inside)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: [_currentLocation!, work],
                      color: colors.brand,
                      strokeWidth: 2,
                      pattern: StrokePattern.dashed(segments: const [6, 6]),
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  if (work != null)
                    Marker(
                      point: work,
                      width: 40,
                      height: 40,
                      child: _OfficePin(color: colors.brand),
                    ),
                  if (_currentLocation != null)
                    Marker(
                      point: _currentLocation!,
                      width: 40,
                      height: 40,
                      child: const _MeDot(),
                    ),
                ],
              ),
            ],
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  _FloatingIcon(
                    icon: Icons.arrow_back_rounded,
                    tooltip: 'Back',
                    onTap: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  _FloatingIcon(
                    icon: Icons.my_location_rounded,
                    tooltip: 'Refresh location',
                    color: colors.brand,
                    onTap: () async {
                      await _updateCurrentLocation();
                      if (_currentLocation != null) {
                        _map.move(_currentLocation!, _map.camera.zoom);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: _PunchSheet(
              loading: _actionLoading,
              today: _todayAttendance,
              hasWork: work != null,
              located: _currentLocation != null,
              locationError: _locationError,
              inside: inside,
              distance: _distanceMeters,
              accuracy: _position?.accuracy,
              placeName: user.workAddress ?? 'your work location',
              shiftStart: user.shiftStart,
              shiftEnd: user.shiftEnd,
              fmtDistance: _fmtDistance,
              onPunch: _punch,
              onRetry: _updateCurrentLocation,
            ),
          ),
        ],
      ),
    );
  }
}

class _PunchSheet extends StatelessWidget {
  const _PunchSheet({
    required this.loading,
    required this.today,
    required this.hasWork,
    required this.located,
    required this.locationError,
    required this.inside,
    required this.distance,
    required this.accuracy,
    required this.placeName,
    required this.shiftStart,
    required this.shiftEnd,
    required this.fmtDistance,
    required this.onPunch,
    required this.onRetry,
  });

  final bool loading;
  final AttendanceModel? today;
  final bool hasWork;
  final bool located;
  final String? locationError;
  final bool inside;
  final double? distance;
  final double? accuracy;
  final String placeName;
  final String shiftStart;
  final String shiftEnd;
  final String Function(double) fmtDistance;
  final VoidCallback onPunch;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final checkedIn = today?.checkIn != null;
    final done = today?.checkOut != null;
    final now = AttendanceClock.now();
    final start = AttendanceClock.parseMinutes(shiftStart) ?? 540;
    final late =
        AttendanceClock.minutesOfDay(now) >
        start + AppConstants.lateGracePeriodMinutes;
    final end = AttendanceClock.parseMinutes(shiftEnd) ?? 1080;
    // Punch-in closes when the shift ends (the server rejects it too).
    final closed = !checkedIn && AttendanceClock.minutesOfDay(now) >= end;
    final finished = done || closed;

    late final IconData icon;
    late final Color fg;
    late final Color bg;
    late final String title;
    late final String subtitle;
    if (done) {
      (icon, fg, bg) = (
        Icons.check_rounded,
        colors.success,
        colors.successSoft,
      );
      title = 'Done for today';
      subtitle = 'Worked ${today!.workDurationFormatted}';
    } else if (closed) {
      (icon, fg, bg) = (
        Icons.schedule_rounded,
        colors.warning,
        colors.warningSoft,
      );
      title = 'Your shift is over';
      subtitle =
          'Punch-in closed at ${AttendanceClock.formatMinutes(end)}. '
          'See you tomorrow.';
    } else if (!hasWork) {
      (icon, fg, bg) = (
        Icons.location_off_outlined,
        colors.warning,
        colors.warningSoft,
      );
      title = 'No work location yet';
      subtitle = 'Ask your admin to assign one before you can punch in.';
    } else if (!located) {
      (icon, fg, bg) = (
        Icons.gps_not_fixed_rounded,
        colors.warning,
        colors.warningSoft,
      );
      title = locationError == null ? 'Finding you…' : 'Location is off';
      subtitle = locationError ?? 'Getting a GPS fix.';
    } else if (inside) {
      (icon, fg, bg) = (
        Icons.check_rounded,
        colors.success,
        colors.successSoft,
      );
      title = 'You’re inside the zone';
      subtitle = '$placeName · ${fmtDistance(distance ?? 0)} from centre';
    } else {
      (icon, fg, bg) = (
        Icons.wrong_location_outlined,
        colors.danger,
        colors.dangerSoft,
      );
      title = 'You’re not at your work location';
      subtitle =
          '${fmtDistance(distance ?? 0)} from $placeName. Move inside the circle to punch.';
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.xxl),
        ),
        boxShadow: AppShadows.raised,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.borderStrong,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: bg,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: fg, size: 22),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(
                          subtitle,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (located && hasWork && !finished) ...[
                const SizedBox(height: AppSpacing.lg),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: colors.surfaceMuted,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Row(
                    children: [
                      _Stat('Time', DateFormat('h:mm a').format(now)),
                      _Stat(
                        'Status',
                        checkedIn ? 'Checked in' : (late ? 'Late' : 'On time'),
                        color: checkedIn
                            ? null
                            : (late ? colors.warning : colors.success),
                      ),
                      _Stat(
                        'GPS',
                        accuracy == null ? '—' : '±${accuracy!.round()} m',
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              if (finished)
                AppButton(
                  label: 'Back to home',
                  variant: AppButtonVariant.secondary,
                  onPressed: () => Navigator.pop(context),
                )
              else if (located && hasWork && !inside) ...[
                const AppBanner(
                  icon: Icons.tips_and_updates_outlined,
                  tone: BannerTone.warning,
                  child: Text(
                    'Still stuck? Turn off fake-GPS apps and set your phone’s '
                    'date & time to automatic.',
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                AppButton(label: 'Try again', onPressed: onRetry),
              ] else
                SizedBox(
                  height: 60,
                  child: AppButton(
                    label: checkedIn ? 'Punch out' : 'Punch in',
                    icon: checkedIn
                        ? Icons.logout_rounded
                        : Icons.login_rounded,
                    loading: loading,
                    onPressed: (located && inside && !loading) ? onPunch : null,
                  ),
                ),
              if (!finished) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Time is recorded by our server, not your phone',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, {this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
              color: color ?? context.colors.textPrimary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _FloatingIcon extends StatelessWidget {
  const _FloatingIcon({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: colors.surface,
      shape: CircleBorder(side: BorderSide(color: colors.border)),
      elevation: 2,
      shadowColor: Colors.black26,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onTap,
        icon: Icon(icon, color: color ?? colors.textPrimary),
      ),
    );
  }
}

class _OfficePin extends StatelessWidget {
  const _OfficePin({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: AppShadows.raised,
      ),
      child: const Icon(Icons.business_rounded, size: 18, color: Colors.white),
    );
  }
}

class _MeDot extends StatelessWidget {
  const _MeDot();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: const Color(0xFF2563EB),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: const [
            BoxShadow(color: Color(0x2E2563EB), spreadRadius: 8),
          ],
        ),
      ),
    );
  }
}
