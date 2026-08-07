import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:async';
import 'dart:io';
import 'package:attendance_app/core/di/injection.dart';
import 'package:attendance_app/core/error/app_exception.dart';
import 'package:attendance_app/core/theme/app_colors.dart';
import 'package:attendance_app/core/theme/app_spacing.dart';
import 'package:attendance_app/core/widgets/app_loader.dart';
import 'package:attendance_app/core/widgets/pressable.dart';
import 'package:attendance_app/data/datasources/analytics_service.dart';
import 'package:attendance_app/domain/repositories/attendance_repository.dart';
import 'package:attendance_app/data/datasources/location_service.dart';
import 'package:attendance_app/features/shared/user_provider.dart';
import 'package:attendance_app/data/models/attendance_model.dart';

class MarkAttendanceScreen extends StatefulWidget {
  const MarkAttendanceScreen({super.key});
  @override
  State<MarkAttendanceScreen> createState() => _MarkAttendanceScreenState();
}

class _MarkAttendanceScreenState extends State<MarkAttendanceScreen> {
  final LocationService _locationService = sl<LocationService>();
  final AttendanceRepository _attendance = sl<AttendanceRepository>();
  LatLng? _currentLocation;
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
      _todayAttendance = await _attendance.getTodayAttendance(
        prov.company!.id,
        prov.user!.id,
      );
    }
    await _updateCurrentLocation();
    setState(() => _isLoading = false);
  }

  Future<void> _updateCurrentLocation() async {
    try {
      final pos = await _locationService.getCurrentLocation();
      if (pos != null && mounted) {
        setState(() => _currentLocation = LatLng(pos.latitude, pos.longitude));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Location error: $e')));
      }
    }
  }

  bool get _isNearby {
    final user = Provider.of<UserProvider>(context, listen: false).user;
    if (_currentLocation == null ||
        user?.workLatitude == null ||
        user?.workLongitude == null) {
      return false;
    }
    return _locationService.isWithinRadius(
      _currentLocation!,
      LatLng(user!.workLatitude!, user.workLongitude!),
      user.workRadius,
    );
  }

  /// Straight-line distance in metres from the employee to the work location,
  /// or null when either point is unknown.
  double? get _distanceMeters {
    final user = Provider.of<UserProvider>(context, listen: false).user;
    if (_currentLocation == null ||
        user?.workLatitude == null ||
        user?.workLongitude == null) {
      return null;
    }
    return const Distance().as(
      LengthUnit.Meter,
      _currentLocation!,
      LatLng(user!.workLatitude!, user.workLongitude!),
    );
  }

  String _fmtDistance(double m) =>
      m >= 1000 ? '${(m / 1000).toStringAsFixed(1)} km' : '${m.round()} m';

  Future<void> _checkIn() async {
    final prov = Provider.of<UserProvider>(context, listen: false);
    final user = prov.user!;
    final company = prov.company!;

    if (_currentLocation == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Getting location...')));
      return;
    }

    if (user.workLatitude == null || user.workLongitude == null) {
      _showErrorDialog(
        'No Work Location',
        'Your admin has not assigned a work location yet.',
      );
      return;
    }

    if (!_isNearby) {
      _showErrorDialog(
        'Outside Range',
        'You are too far from the work location.',
      );
      return;
    }

    setState(() => _actionLoading = true);

    try {
      // Optional: capture selfie
      String? selfiePath;
      try {
        final picker = ImagePicker();
        final photo = await picker.pickImage(
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
        // Camera not available or user cancelled — proceed without selfie
      }

      final outcome = await _attendance.checkIn(
        companyId: company.id,
        employeeId: user.id,
        employeeName: user.name,
        shiftStart: user.shiftStart,
        location: {
          'latitude': _currentLocation!.latitude,
          'longitude': _currentLocation!.longitude,
        },
        selfieStoragePath: selfiePath,
      );
      unawaited(
        sl<AnalyticsService>().logCheckIn(
          offline: outcome == CheckOutcome.queuedOffline,
        ),
      );
      if (outcome == CheckOutcome.queuedOffline) {
        _showSuccessDialog(
          'Saved Offline',
          "You're offline — your check-in is saved and will sync "
              'automatically when a connection is available.',
        );
      } else {
        _todayAttendance = await _attendance.getTodayAttendance(
          company.id,
          user.id,
        );
        if (mounted) setState(() {});
        _showSuccessDialog('Checked In', 'Your attendance has been recorded.');
      }
    } catch (e) {
      if (mounted) {
        final message = e is AppException
            ? e.message
            : 'Check-in failed. Please try again.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: context.colors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _checkOut() async {
    final prov = Provider.of<UserProvider>(context, listen: false);
    final user = prov.user!;
    final company = prov.company!;

    setState(() => _actionLoading = true);
    try {
      if (_currentLocation == null) {
        await _updateCurrentLocation();
        if (_currentLocation == null) {
          throw StateError('Current location is required to check out.');
        }
      }
      final outcome = await _attendance.checkOut(
        companyId: company.id,
        employeeId: user.id,
        location: {
          'latitude': _currentLocation!.latitude,
          'longitude': _currentLocation!.longitude,
        },
      );
      unawaited(
        sl<AnalyticsService>().logCheckOut(
          offline: outcome == CheckOutcome.queuedOffline,
        ),
      );
      if (outcome == CheckOutcome.queuedOffline) {
        _showSuccessDialog(
          'Saved Offline',
          "You're offline — your check-out is saved and will sync "
              'automatically when a connection is available.',
        );
      } else {
        _todayAttendance = await _attendance.getTodayAttendance(
          company.id,
          user.id,
        );
        setState(() {});
        _showSuccessDialog('Checked Out', 'You have successfully checked out.');
      }
    } catch (e) {
      if (mounted) {
        final message = e is AppException
            ? e.message
            : 'Check-out failed. Please try again.';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserProvider>(context).user;
    if (user == null || _isLoading) {
      return const Scaffold(body: AppLoader());
    }

    final hasWorkLoc = user.workLatitude != null && user.workLongitude != null;
    final workLoc = hasWorkLoc
        ? LatLng(user.workLatitude!, user.workLongitude!)
        : const LatLng(20.5937, 78.9629);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Live Check-in'),
        backgroundColor: Colors.transparent,
      ),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: _currentLocation ?? workLoc,
              initialZoom: hasWorkLoc ? 16.0 : 5.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.punchin.app',
              ),
              if (hasWorkLoc)
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: workLoc,
                      color:
                          (_isNearby
                                  ? context.colors.success
                                  : context.colors.danger)
                              .withValues(alpha: 0.16),
                      borderStrokeWidth: 2,
                      borderColor: _isNearby
                          ? context.colors.success
                          : context.colors.danger,
                      useRadiusInMeter: true,
                      radius: user.workRadius,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  if (hasWorkLoc)
                    Marker(
                      point: workLoc,
                      width: 50,
                      height: 50,
                      child: _buildMarker(Icons.business, context.colors.brand),
                    ),
                  if (_currentLocation != null)
                    Marker(
                      point: _currentLocation!,
                      width: 50,
                      height: 50,
                      child: _buildMarker(
                        Icons.person_pin_circle,
                        context.colors.success,
                      ),
                    ),
                ],
              ),
            ],
          ),
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: _buildActionPanel(),
          ),
          Positioned(
            top: 100,
            right: 20,
            child: FloatingActionButton.small(
              heroTag: 'refresh_loc',
              onPressed: _updateCurrentLocation,
              backgroundColor: context.colors.surface,
              foregroundColor: context.colors.textPrimary,
              child: const Icon(Icons.my_location_rounded),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarker(IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [BoxShadow(color: color.withAlpha(100), blurRadius: 10)],
      ),
      child: Icon(icon, color: AppColors.onColor(color), size: 22),
    );
  }

  Widget _buildActionPanel() {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final isNearby = _isNearby;
    final statusColor = isNearby ? colors.success : colors.warning;
    final distance = _distanceMeters;

    final String subtitle;
    if (distance == null) {
      subtitle = 'Locating you…';
    } else if (isNearby) {
      subtitle = 'You’re ${_fmtDistance(distance)} from the centre';
    } else {
      subtitle = '${_fmtDistance(distance)} away · move closer to check in';
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.98),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _LivePulse(color: statusColor, active: isNearby),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isNearby ? 'Within range' : 'Out of range',
                      style: text.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: text.bodySmall?.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_actionLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: AppLoader(),
            )
          else if (_todayAttendance == null)
            _actionBtn('Confirm check-in', colors.brand, _checkIn)
          else if (_todayAttendance!.checkOut == null)
            _actionBtn('Complete check-out', colors.danger, _checkOut)
          else
            _completionStatus(),
        ],
      ),
    );
  }

  Widget _actionBtn(String label, Color color, VoidCallback onPressed) {
    final fg = AppColors.onColor(color);
    return Pressable(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.35),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              label.contains('out')
                  ? Icons.logout_rounded
                  : Icons.check_circle_rounded,
              color: fg,
              size: 20,
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              label,
              style: TextStyle(
                color: fg,
                fontSize: 15,
                letterSpacing: 0.2,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _completionStatus() {
    final colors = context.colors;
    return Column(
      children: [
        Icon(Icons.verified_rounded, color: colors.success, size: 48),
        const SizedBox(height: 8),
        Text('Duty Completed', style: Theme.of(context).textTheme.titleLarge),
        if (_todayAttendance != null)
          Text(
            _todayAttendance!.workDurationFormatted,
            style: Theme.of(context).textTheme.bodySmall,
          ),
      ],
    );
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error_outline, color: context.colors.danger),
            const SizedBox(width: 12),
            Expanded(child: Text(title)),
          ],
        ),
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

  void _showSuccessDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: context.colors.success),
            const SizedBox(width: 12),
            Expanded(child: Text(title)),
          ],
        ),
        content: Text(message),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('GREAT'),
          ),
        ],
      ),
    );
  }
}

/// A location dot that emits a soft, repeating "radar" pulse when [active]
/// (i.e. the employee is inside the geofence) — a subtle live signal that the
/// GPS lock is good, the way a maps app animates your position.
class _LivePulse extends StatefulWidget {
  const _LivePulse({required this.color, required this.active});

  final Color color;
  final bool active;

  @override
  State<_LivePulse> createState() => _LivePulseState();
}

class _LivePulseState extends State<_LivePulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 44,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (widget.active)
            AnimatedBuilder(
              animation: _c,
              builder: (context, _) {
                final t = _c.value;
                return Container(
                  width: 24 + 20 * t,
                  height: 24 + 20 * t,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.color.withValues(alpha: (1 - t) * 0.28),
                  ),
                );
              },
            ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: widget.color.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: Icon(
              widget.active
                  ? Icons.location_on_rounded
                  : Icons.location_off_rounded,
              color: widget.color,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
}
