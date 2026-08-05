import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

import 'package:attendance_app/core/theme/app_colors.dart';
import 'package:attendance_app/core/theme/app_spacing.dart';
import 'package:attendance_app/core/widgets/app_button.dart';

class WorkLocationPicker extends StatefulWidget {
  final double? initialLat;
  final double? initialLng;
  final double initialRadius;
  const WorkLocationPicker({
    super.key,
    this.initialLat,
    this.initialLng,
    this.initialRadius = 100,
  });
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
        final parts = [
          p.street,
          p.subLocality,
          p.locality,
          p.administrativeArea,
        ].where((s) => s != null && s.isNotEmpty);
        setState(() => _address = parts.join(', '));
      }
    } catch (_) {
      setState(
        () => _address = '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}',
      );
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
      setState(() {
        _pickedLat = pos.latitude;
        _pickedLng = pos.longitude;
      });
      _mapController.move(LatLng(pos.latitude, pos.longitude), 17);
      _reverseGeocode(pos.latitude, pos.longitude);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  void _onTap(TapPosition tapPos, LatLng point) {
    setState(() {
      _pickedLat = point.latitude;
      _pickedLng = point.longitude;
    });
    _reverseGeocode(point.latitude, point.longitude);
  }

  void _confirm() {
    if (_pickedLat == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Select a location first')));
      return;
    }
    Navigator.pop(context, {
      'latitude': _pickedLat,
      'longitude': _pickedLng,
      'radius': _radius,
      'address': _address,
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      appBar: AppBar(title: const Text('Pick Work Location')),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _center,
              initialZoom: _initialZoom,
              onTap: _onTap,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.punchin.app',
              ),
              if (_pickedLat != null && _pickedLng != null) ...[
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: LatLng(_pickedLat!, _pickedLng!),
                      radius: _radius,
                      useRadiusInMeter: true,
                      color: colors.brand.withValues(alpha: 0.2),
                      borderColor: colors.brand,
                      borderStrokeWidth: 2,
                    ),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(_pickedLat!, _pickedLng!),
                      width: 44,
                      height: 44,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: colors.brand,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: colors.brand.withValues(alpha: 0.4),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.business_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppRadius.xl),
                ),
                border: Border(top: BorderSide(color: colors.border)),
              ),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.lg,
                AppSpacing.xl,
                AppSpacing.xxl + AppSpacing.xs,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'WORK LOCATION',
                    style: TextStyle(
                      color: colors.textTertiary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_rounded,
                        color: colors.brand,
                        size: 20,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          _loadingAddress ? 'Getting address…' : _address,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: [
                      Text(
                        'Geofence radius',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: colors.brandSoft,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Text(
                          '${_radius.round()} m',
                          style: TextStyle(
                            color: colors.brand,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: _radius,
                    min: 50,
                    max: 500,
                    divisions: 18,
                    label: '${_radius.round()} m',
                    onChanged: (v) => setState(() => _radius = v),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppButton(
                    label: 'Confirm location',
                    icon: Icons.check_rounded,
                    onPressed: _confirm,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 260),
        child: FloatingActionButton(
          onPressed: _goToCurrentLocation,
          child: const Icon(Icons.my_location),
        ),
      ),
    );
  }
}
