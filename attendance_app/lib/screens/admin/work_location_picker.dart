import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class WorkLocationPicker extends StatefulWidget {
  final double? initialLat;
  final double? initialLng;
  final double initialRadius;
  const WorkLocationPicker({super.key, this.initialLat, this.initialLng, this.initialRadius = 100});
  @override
  State<WorkLocationPicker> createState() => _WorkLocationPickerState();
}

class _WorkLocationPickerState extends State<WorkLocationPicker> {
  final MapController _mapController = MapController();
  double? _pickedLat;
  double? _pickedLng;
  double _radius = 100;
  String _address = 'Tap on map to set location';
  bool _loadingAddress = false;

  @override
  void initState() {
    super.initState();
    _pickedLat = widget.initialLat;
    _pickedLng = widget.initialLng;
    _radius = widget.initialRadius;
    if (_pickedLat != null && _pickedLng != null) {
      _reverseGeocode(_pickedLat!, _pickedLng!);
    }
  }

  LatLng get _center => _pickedLat != null && _pickedLng != null
      ? LatLng(_pickedLat!, _pickedLng!)
      : const LatLng(20.5937, 78.9629);

  double get _initialZoom => _pickedLat != null ? 17.0 : 5.0;

  Future<void> _reverseGeocode(double lat, double lng) async {
    setState(() => _loadingAddress = true);
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final parts = [p.street, p.subLocality, p.locality, p.administrativeArea]
            .where((s) => s != null && s.isNotEmpty);
        setState(() => _address = parts.join(', '));
      }
    } catch (_) {
      setState(() => _address = '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}');
    } finally {
      setState(() => _loadingAddress = false);
    }
  }

  Future<void> _goToCurrentLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
        if (perm == LocationPermission.denied) return;
      }
      if (perm == LocationPermission.deniedForever) return;
      final pos = await Geolocator.getCurrentPosition();
      setState(() { _pickedLat = pos.latitude; _pickedLng = pos.longitude; });
      _mapController.move(LatLng(pos.latitude, pos.longitude), 17);
      _reverseGeocode(pos.latitude, pos.longitude);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  void _onTap(TapPosition tapPos, LatLng point) {
    setState(() { _pickedLat = point.latitude; _pickedLng = point.longitude; });
    _reverseGeocode(point.latitude, point.longitude);
  }

  void _confirm() {
    if (_pickedLat == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select a location first')));
      return;
    }
    Navigator.pop(context, {'latitude': _pickedLat, 'longitude': _pickedLng, 'radius': _radius, 'address': _address});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(title: const Text('Pick Work Location'), backgroundColor: const Color(0xFF1E293B)),
      body: Stack(children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(initialCenter: _center, initialZoom: _initialZoom, onTap: _onTap),
          children: [
            TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.punchin.app'),
            if (_pickedLat != null && _pickedLng != null) ...[
              CircleLayer(circles: [
                CircleMarker(point: LatLng(_pickedLat!, _pickedLng!), radius: _radius, useRadiusInMeter: true,
                  color: const Color(0xFF6366F1).withAlpha(50), borderColor: const Color(0xFF6366F1), borderStrokeWidth: 2),
              ]),
              MarkerLayer(markers: [
                Marker(point: LatLng(_pickedLat!, _pickedLng!), width: 40, height: 40,
                  child: const Icon(Icons.business, color: Colors.orange, size: 36)),
              ]),
            ],
          ],
        ),
        Positioned(left: 0, right: 0, bottom: 0, child: Container(
          decoration: const BoxDecoration(color: Color(0xFF1E293B), borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.location_on, color: Color(0xFF6366F1)),
              const SizedBox(width: 8),
              Expanded(child: Text(_loadingAddress ? 'Getting address...' : _address, style: const TextStyle(color: Colors.white, fontSize: 14), maxLines: 2, overflow: TextOverflow.ellipsis)),
            ]),
            const SizedBox(height: 16),
            Text('Geofence Radius: ${_radius.round()} m', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
            Slider(value: _radius, min: 50, max: 500, divisions: 18, activeColor: const Color(0xFF6366F1), onChanged: (v) => setState(() => _radius = v)),
            const SizedBox(height: 8),
            ElevatedButton(onPressed: _confirm, style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1), foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              child: const Text('Confirm Location', style: TextStyle(fontWeight: FontWeight.bold))),
          ]),
        )),
      ]),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 260),
        child: FloatingActionButton(onPressed: _goToCurrentLocation, backgroundColor: const Color(0xFF6366F1),
          child: const Icon(Icons.my_location, color: Colors.white)),
      ),
    );
  }
}
