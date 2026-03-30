import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../utils/user_provider.dart';
import '../../services/location_service.dart';
import '../../services/database_service.dart';
import '../../models/attendance_model.dart';
import 'package:intl/intl.dart';

class MarkAttendanceScreen extends StatefulWidget {
  const MarkAttendanceScreen({super.key});

  @override
  State<MarkAttendanceScreen> createState() => _MarkAttendanceScreenState();
}

class _MarkAttendanceScreenState extends State<MarkAttendanceScreen> {
  final LocationService _locationService = LocationService();
  final DatabaseService _db = DatabaseService();
  LatLng? _currentLocation;
  bool _isLoading = true;
  AttendanceModel? _todayAttendance;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final user = Provider.of<UserProvider>(context, listen: false).user;
    if (user != null) {
      _todayAttendance = await _db.getTodayAttendance(user.id);
    }
    await _updateCurrentLocation();
    setState(() => _isLoading = false);
  }

  Future<void> _updateCurrentLocation() async {
    try {
      final pos = await _locationService.getCurrentLocation();
      if (pos != null) {
        setState(() {
          _currentLocation = LatLng(pos.latitude, pos.longitude);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error getting location: $e')),
        );
      }
    }
  }

  void _checkIn() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final user = userProvider.user!;

    if (_currentLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Getting location...')));
      return;
    }

    final workLat = user.assignedLocation!['lat']!;
    final workLng = user.assignedLocation!['lng']!;
    final workLocation = LatLng(workLat, workLng);

    // 1. Validate Distance
    final isWithin = _locationService.isWithinRadius(
      _currentLocation!,
      workLocation,
      user.radius ?? 100,
    );

    if (!isWithin) {
      _showErrorDialog('Outside Location', 'You are too far from the work location to check in.');
      return;
    }

    // 2. Validate Time
    String status = 'On-time';
    if (user.shiftStart != null) {
      final now = DateTime.now();
      final shiftStartString = user.shiftStart!;
      try {
        final shiftStart = DateFormat('HH:mm').parse(shiftStartString);
        final currentTime = DateTime(now.year, now.month, now.day, now.hour, now.minute);
        final startTime = DateTime(now.year, now.month, now.day, shiftStart.hour, shiftStart.minute);

        if (currentTime.isAfter(startTime.add(const Duration(minutes: 15)))) {
          status = 'Late';
        }
      } catch (e) {
        // Fallback or log error
      }
    }

    // 3. Log Attendance
    final attendance = AttendanceModel(
      id: '', // Will be generated
      userId: user.id,
      date: DateTime.now(),
      checkInTime: DateTime.now(),
      location: {'lat': _currentLocation!.latitude, 'lng': _currentLocation!.longitude},
      status: status,
      companyId: user.companyId,
    );

    await _db.logAttendance(attendance);
    setState(() => _todayAttendance = attendance);
    _showSuccessDialog('Checked In', 'You have successfully checked in as $status.');
  }

  void _checkOut() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final user = userProvider.user!;

    await _db.checkOut(user.id, DateTime.now());
    _todayAttendance = await _db.getTodayAttendance(user.id);
    setState(() {});
    _showSuccessDialog('Checked Out', 'You have successfully checked out.');
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserProvider>(context).user;
    if (user == null || _isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final workLat = user.assignedLocation!['lat']!;
    final workLng = user.assignedLocation!['lng']!;
    final workLocation = LatLng(workLat, workLng);

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
              initialCenter: workLocation,
              initialZoom: 16.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.attendance_app',
                tileBuilder: (context, tileWidget, tile) {
                  return ColorFiltered(
                    colorFilter: const ColorFilter.matrix([
                      -0.2126, -0.7152, -0.0722, 0, 255,
                      -0.2126, -0.7152, -0.0722, 0, 255,
                      -0.2126, -0.7152, -0.0722, 0, 255,
                      0, 0, 0, 1, 0,
                    ]),
                    child: tileWidget,
                  );
                },
              ),
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: workLocation,
                    color: const Color(0xFF6366F1).withOpacity(0.15),
                    borderStrokeWidth: 2,
                    borderColor: const Color(0xFF6366F1),
                    useRadiusInMeter: true,
                    radius: user.radius ?? 100,
                  ),
                ],
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: workLocation,
                    width: 60,
                    height: 60,
                    child: _buildLocationMarker(Icons.business_rounded, const Color(0xFF6366F1)),
                  ),
                  if (_currentLocation != null)
                    Marker(
                      point: _currentLocation!,
                      width: 60,
                      height: 60,
                      child: _buildLocationMarker(Icons.person_pin_circle_rounded, const Color(0xFF10B981), isLive: true),
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
              backgroundColor: const Color(0xFF1E293B),
              foregroundColor: Colors.white,
              child: const Icon(Icons.my_location_rounded),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationMarker(IconData icon, Color color, {bool isLive = false}) {
    return Stack(
      alignment: Alignment.center,
      children: [
        if (isLive)
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 1.0, end: 2.0),
            duration: const Duration(seconds: 2),
            curve: Curves.easeInOut,
            builder: (context, value, child) {
              return Container(
                width: 30 * value,
                height: 30 * value,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withOpacity(0.3 * (2 - value)),
                ),
              );
            },
          ),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.4),
                blurRadius: 10,
                spreadRadius: 2,
              )
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
      ],
    );
  }

  Widget _buildActionPanel() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.95),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 30,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildStatusHeader(),
          const SizedBox(height: 24),
          if (_todayAttendance == null)
            _buildCustomButton('CONFIRM CHECK-IN', const Color(0xFF10B981), _checkIn)
          else if (_todayAttendance!.checkOutTime == null)
            _buildCustomButton('COMPLETE CHECK-OUT', const Color(0xFFF43F5E), _checkOut)
          else
            _buildCompletionStatus(),
        ],
      ),
    );
  }

  Widget _buildStatusHeader() {
    bool isNearby = false;
    if (_currentLocation != null) {
      final user = Provider.of<UserProvider>(context, listen: false).user!;
      final workLocation = LatLng(user.assignedLocation!['lat']!, user.assignedLocation!['lng']!);
      isNearby = _locationService.isWithinRadius(_currentLocation!, workLocation, user.radius ?? 100);
    }

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: (isNearby ? const Color(0xFF10B981) : const Color(0xFFF59E0B)).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isNearby ? Icons.location_on_rounded : Icons.location_off_rounded,
            color: isNearby ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
            size: 20,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isNearby ? 'In Range' : 'Out of Range',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Text(
                isNearby ? 'You are at the work location' : 'Move closer to the workplace',
                style: TextStyle(color: Colors.grey[400], fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCustomButton(String label, Color color, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        minimumSize: const Size(double.infinity, 60),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 0,
      ),
      child: Text(
        label,
        style: const TextStyle(letterSpacing: 1.2, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildCompletionStatus() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          const Icon(Icons.verified_rounded, color: Color(0xFF10B981), size: 48),
          const SizedBox(height: 8),
          const Text(
            'Duty Completed',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          Text(
            'See you tomorrow!',
            style: TextStyle(color: Colors.grey[400], fontSize: 13),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Color(0xFFF43F5E)),
            const SizedBox(width: 12),
            Text(title, style: const TextStyle(color: Colors.white)),
          ],
        ),
        content: Text(message, style: TextStyle(color: Colors.grey[400])),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('UNDERSTOOD', style: TextStyle(color: Color(0xFF6366F1))),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981)),
            const SizedBox(width: 12),
            Text(title, style: const TextStyle(color: Colors.white)),
          ],
        ),
        content: Text(message, style: TextStyle(color: Colors.grey[400])),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              minimumSize: const Size(100, 44),
            ),
            child: const Text('GREAT'),
          ),
        ],
      ),
    );
  }
}
