import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../utils/user_provider.dart';
import '../../services/location_service.dart';
import '../../services/database_service.dart';
import '../../services/storage_service.dart';
import '../../models/attendance_model.dart';

class MarkAttendanceScreen extends StatefulWidget {
  const MarkAttendanceScreen({super.key});
  @override
  State<MarkAttendanceScreen> createState() => _MarkAttendanceScreenState();
}

class _MarkAttendanceScreenState extends State<MarkAttendanceScreen> {
  final LocationService _locationService = LocationService();
  final DatabaseService _db = DatabaseService();
  final StorageService _storage = StorageService();
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
      _todayAttendance =
          await _db.getTodayAttendance(prov.company!.id, prov.user!.id);
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
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Location error: $e')));
      }
    }
  }

  bool get _isNearby {
    final user = Provider.of<UserProvider>(context, listen: false).user;
    if (_currentLocation == null ||
        user?.workLatitude == null ||
        user?.workLongitude == null) return false;
    return _locationService.isWithinRadius(
      _currentLocation!,
      LatLng(user!.workLatitude!, user.workLongitude!),
      user.workRadius,
    );
  }

  Future<void> _checkIn() async {
    final prov = Provider.of<UserProvider>(context, listen: false);
    final user = prov.user!;
    final company = prov.company!;

    if (_currentLocation == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Getting location...')));
      return;
    }

    if (user.workLatitude == null || user.workLongitude == null) {
      _showErrorDialog('No Work Location',
          'Your admin has not assigned a work location yet.');
      return;
    }

    if (!_isNearby) {
      _showErrorDialog(
          'Outside Range', 'You are too far from the work location.');
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
            maxWidth: 640);
        if (photo != null) {
          selfiePath = await _storage.uploadSelfie(
              company.id, user.id, File(photo.path));
        }
      } catch (_) {
        // Camera not available or user cancelled — proceed without selfie
      }

      // Calculate late status
      final now = DateTime.now();
      bool isLate = false;
      String status = 'present';
      try {
        final parts = user.shiftStart.split(':');
        final shiftStart = DateTime(now.year, now.month, now.day,
            int.parse(parts[0]), int.parse(parts[1]));
        if (now.isAfter(shiftStart.add(const Duration(minutes: 15)))) {
          isLate = true;
          status = 'late';
        }
      } catch (_) {}

      final dateStr = DateFormat('yyyy-MM-dd').format(now);
      final docId = '${user.id}_$dateStr';
      final record = AttendanceModel(
        id: docId,
        employeeId: user.id,
        companyId: company.id,
        employeeName: user.name,
        date: dateStr,
        checkIn: now,
        status: status,
        isLate: isLate,
        checkInLocation: {
          'latitude': _currentLocation!.latitude,
          'longitude': _currentLocation!.longitude,
        },
        selfieStoragePath: selfiePath,
      );

      await _db.checkIn(company.id, record);
      setState(() => _todayAttendance = record);
      _showSuccessDialog(
          'Checked In', 'You have successfully checked in as $status.');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Check-in failed: $e'),
              backgroundColor: const Color(0xFFEF4444)),
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
      Map<String, dynamic>? location;
      if (_currentLocation != null) {
        location = {
          'latitude': _currentLocation!.latitude,
          'longitude': _currentLocation!.longitude,
        };
      }
      await _db.checkOut(company.id, _todayAttendance!.id, DateTime.now(),
          location: location);
      _todayAttendance =
          await _db.getTodayAttendance(company.id, user.id);
      setState(() {});
      _showSuccessDialog('Checked Out', 'You have successfully checked out.');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Check-out failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserProvider>(context).user;
    if (user == null || _isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F172A),
        body: Center(
            child: CircularProgressIndicator(color: Color(0xFF6366F1))),
      );
    }

    final hasWorkLoc = user.workLatitude != null && user.workLongitude != null;
    final workLoc = hasWorkLoc
        ? LatLng(user.workLatitude!, user.workLongitude!)
        : const LatLng(20.5937, 78.9629);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
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
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.punchin.app',
              ),
              if (hasWorkLoc)
                CircleLayer(circles: [
                  CircleMarker(
                    point: workLoc,
                    color: (_isNearby
                            ? const Color(0xFF10B981)
                            : const Color(0xFFEF4444))
                        .withAlpha(40),
                    borderStrokeWidth: 2,
                    borderColor: _isNearby
                        ? const Color(0xFF10B981)
                        : const Color(0xFFEF4444),
                    useRadiusInMeter: true,
                    radius: user.workRadius,
                  ),
                ]),
              MarkerLayer(markers: [
                if (hasWorkLoc)
                  Marker(
                    point: workLoc,
                    width: 50,
                    height: 50,
                    child: _buildMarker(Icons.business, const Color(0xFF6366F1)),
                  ),
                if (_currentLocation != null)
                  Marker(
                    point: _currentLocation!,
                    width: 50,
                    height: 50,
                    child: _buildMarker(
                        Icons.person_pin_circle, const Color(0xFF10B981)),
                  ),
              ]),
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
              backgroundColor: const Color(0xFF1E293B),
              foregroundColor: Colors.white,
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
      child: Icon(icon, color: Colors.white, size: 22),
    );
  }

  Widget _buildActionPanel() {
    final isNearby = _isNearby;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withAlpha(245),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withAlpha(25)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (isNearby ? const Color(0xFF10B981) : const Color(0xFFF59E0B))
                  .withAlpha(25),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isNearby ? Icons.location_on : Icons.location_off,
              color: isNearby ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(isNearby ? 'In Range' : 'Out of Range',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.white)),
                  Text(
                      isNearby
                          ? 'You are at the work location'
                          : 'Move closer to the workplace',
                      style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                ]),
          ),
        ]),
        const SizedBox(height: 20),
        if (_actionLoading)
          const Center(
              child: CircularProgressIndicator(color: Color(0xFF6366F1)))
        else if (_todayAttendance == null)
          _actionBtn(
              'CONFIRM CHECK-IN', const Color(0xFF10B981), _checkIn)
        else if (_todayAttendance!.checkOut == null)
          _actionBtn(
              'COMPLETE CHECK-OUT', const Color(0xFFF43F5E), _checkOut)
        else
          _completionStatus(),
      ]),
    );
  }

  Widget _actionBtn(String label, Color color, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        minimumSize: const Size(double.infinity, 56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: Text(label,
          style: const TextStyle(
              letterSpacing: 1.2, fontWeight: FontWeight.bold)),
    );
  }

  Widget _completionStatus() {
    return Column(children: [
      const Icon(Icons.verified_rounded, color: Color(0xFF10B981), size: 48),
      const SizedBox(height: 8),
      const Text('Duty Completed',
          style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: Colors.white)),
      if (_todayAttendance != null)
        Text(_todayAttendance!.workDurationFormatted,
            style: TextStyle(color: Colors.grey[400], fontSize: 13)),
    ]);
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          const Icon(Icons.error_outline, color: Color(0xFFF43F5E)),
          const SizedBox(width: 12),
          Text(title, style: const TextStyle(color: Colors.white)),
        ]),
        content: Text(message, style: TextStyle(color: Colors.grey[400])),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK', style: TextStyle(color: Color(0xFF6366F1)))),
        ],
      ),
    );
  }

  void _showSuccessDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          const Icon(Icons.check_circle, color: Color(0xFF10B981)),
          const SizedBox(width: 12),
          Text(title, style: const TextStyle(color: Colors.white)),
        ]),
        content: Text(message, style: TextStyle(color: Colors.grey[400])),
        actions: [
          ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('GREAT')),
        ],
      ),
    );
  }
}
