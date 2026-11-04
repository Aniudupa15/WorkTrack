import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'package:attendance_app/core/constants/app_constants.dart';
import 'package:attendance_app/core/theme/app_colors.dart';
import 'package:attendance_app/core/theme/app_spacing.dart';
import 'package:attendance_app/core/widgets/app_button.dart';
import 'package:attendance_app/core/widgets/app_chip.dart';

/// Place a work location (design 1.5): drag the map under the fixed office
/// pin, search an address, name it and set the punch-in radius.
///
/// Pops with `{name, latitude, longitude, radius, address}`.
class WorkLocationPicker extends StatefulWidget {
  const WorkLocationPicker({
    super.key,
    this.initialLat,
    this.initialLng,
    this.initialRadius = 100,
    this.initialName,
    this.askName = true,
    this.stepLabel,
  });

  final double? initialLat;
  final double? initialLng;
  final double initialRadius;
  final String? initialName;

  /// Show the "Location name" field (off when the caller names it itself).
  final bool askName;

  /// e.g. "Step 4 of 5" during company setup.
  final String? stepLabel;

  @override
  State<WorkLocationPicker> createState() => _WorkLocationPickerState();
}

class _WorkLocationPickerState extends State<WorkLocationPicker> {
  static const _india = LatLng(20.5937, 78.9629);
  static const _radii = [50.0, 100.0, 200.0, 500.0];

  /// The pin sits above the bottom sheet, not at the screen centre.
  static const _pinY = -0.35;

  final _map = MapController();
  final _name = TextEditingController();
  final _search = TextEditingController();
  late LatLng _center;
  late double _radius = widget.initialRadius.clamp(25, 1000).toDouble();
  late bool _placed = widget.initialLat != null;
  String? _address;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _name.text = widget.initialName ?? '';
    _center = widget.initialLat != null && widget.initialLng != null
        ? LatLng(widget.initialLat!, widget.initialLng!)
        : _india;
    if (_placed) {
      _lookupAddress();
    } else {
      _goToMe(quiet: true);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _name.dispose();
    _search.dispose();
    super.dispose();
  }

  /// Screen position of the pin for a map of [size].
  static Offset _pinOffset(Size size) =>
      Offset(size.width / 2, size.height * (1 + _pinY) / 2);

  void _onMoved(MapCamera camera, bool hasGesture) {
    _center = camera.screenOffsetToLatLng(_pinOffset(camera.size));
    if (!hasGesture) return;
    if (!_placed) setState(() => _placed = true);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), _lookupAddress);
  }

  Future<void> _lookupAddress() async {
    final at = _center;
    try {
      final marks = await placemarkFromCoordinates(at.latitude, at.longitude);
      final p = marks.firstOrNull;
      if (p == null || !mounted) return;
      final parts = [
        p.name,
        p.street,
        p.subLocality,
        p.locality,
      ].whereType<String>().where((s) => s.isNotEmpty).toSet().take(3);
      setState(() => _address = parts.join(', '));
    } catch (_) {
      // No geocoder (web) or no network: show the coordinates instead.
      if (mounted) {
        setState(
          () => _address =
              '${at.latitude.toStringAsFixed(5)}, ${at.longitude.toStringAsFixed(5)}',
        );
      }
    }
  }

  Future<void> _searchAddress(String query) async {
    if (query.trim().isEmpty) return;
    try {
      final hits = await locationFromAddress(query.trim());
      final hit = hits.firstOrNull;
      if (hit == null) throw Exception();
      _moveTo(LatLng(hit.latitude, hit.longitude));
      setState(() => _address = query.trim());
    } catch (_) {
      _snack('Couldn’t find that address. Drag the map to the spot instead.');
    }
  }

  Future<void> _goToMe({bool quiet = false}) async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        if (!quiet) _snack('Allow location access to use where you are.');
        return;
      }
      final pos = await Geolocator.getCurrentPosition();
      _moveTo(LatLng(pos.latitude, pos.longitude));
    } catch (_) {
      if (!quiet) _snack('Couldn’t get your location.');
    }
  }

  void _moveTo(LatLng point) {
    _center = point;
    // Move so [point] lands under the pin rather than at the screen centre.
    _map.move(point, 17);
    final camera = _map.camera;
    final shift = camera.size.center(Offset.zero) - _pinOffset(camera.size);
    _map.move(
      camera.screenOffsetToLatLng(camera.size.center(Offset.zero) + shift),
      17,
    );
    _center = point;
    setState(() => _placed = true);
    _lookupAddress();
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _save() {
    if (!_placed) return _snack('Drag the map to your location first.');
    if (widget.askName && _name.text.trim().isEmpty) {
      return _snack('Give this location a name.');
    }
    Navigator.pop(context, {
      'name': _name.text.trim(),
      'latitude': _center.latitude,
      'longitude': _center.longitude,
      'radius': _radius,
      'address': _address,
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          Positioned.fill(
            child: FlutterMap(
              mapController: _map,
              options: MapOptions(
                initialCenter: _center,
                initialZoom: _placed ? 17 : 4.5,
                onPositionChanged: _onMoved,
              ),
              children: [
                TileLayer(
                  urlTemplate: AppConstants.osmTileUrl,
                  userAgentPackageName: AppConstants.packageName,
                ),
              ],
            ),
          ),
          // The zone and pin stay centred; the map moves under them.
          IgnorePointer(
            child: LayoutBuilder(
              builder: (context, box) => Align(
                alignment: const Alignment(0, _pinY),
                child: _ZonePreview(
                  radius: _radius,
                  metersPerPixel: _placed
                      ? _metersPerPixel(_center.latitude, 17)
                      : null,
                  colors: colors,
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  _RoundButton(
                    icon: Icons.arrow_back_rounded,
                    tooltip: 'Back',
                    onTap: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        boxShadow: AppShadows.raised,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.search_rounded,
                            size: 18,
                            color: colors.textTertiary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _search,
                              enabled: !kIsWeb,
                              textInputAction: TextInputAction.search,
                              onSubmitted: _searchAddress,
                              decoration: InputDecoration(
                                isDense: true,
                                filled: false,
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                disabledBorder: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                                hintText: kIsWeb
                                    ? (_address ?? 'Drag the map to the spot')
                                    : (_address ?? 'Search an address'),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppRadius.xxl),
                ),
                boxShadow: AppShadows.raised,
              ),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: SafeArea(
                top: false,
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
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        if (widget.stepLabel != null)
                          Text(
                            widget.stepLabel!,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: colors.textTertiary,
                            ),
                          ),
                        const Spacer(),
                        Text('Drag the map to adjust', style: text.labelSmall),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Add a work location',
                            style: text.titleLarge,
                          ),
                        ),
                        _RoundButton(
                          icon: Icons.my_location_rounded,
                          tooltip: 'Use my current location',
                          color: colors.brand,
                          onTap: _goToMe,
                        ),
                      ],
                    ),
                    if (widget.askName) ...[
                      const SizedBox(height: AppSpacing.md),
                      Text('Location name', style: text.labelMedium),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _name,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          hintText: 'HQ — MG Road',
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Text('Punch-in radius', style: text.labelMedium),
                        const Spacer(),
                        Text(
                          '${_radius.round()} m',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    Slider(
                      value: _radius,
                      min: 25,
                      max: 1000,
                      divisions: 39,
                      onChanged: (v) => setState(() => _radius = v),
                    ),
                    Wrap(
                      spacing: 6,
                      children: [
                        for (final r in _radii)
                          AppChip(
                            label: '${r.round()} m',
                            selected: _radius.round() == r.round(),
                            onTap: () => setState(() => _radius = r),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppButton(label: 'Save location', onPressed: _save),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Web-Mercator ground resolution at [lat] and zoom [z] (256-px tiles).
  static double _metersPerPixel(double lat, double z) =>
      156543.03392 * _cos(lat * 3.141592653589793 / 180) / _pow2(z);
  static double _cos(double x) {
    // cos via Taylor series is plenty for a preview circle.
    final x2 = x * x;
    return 1 - x2 / 2 + x2 * x2 / 24 - x2 * x2 * x2 / 720;
  }

  static double _pow2(double z) {
    var v = 1.0;
    for (var i = 0; i < z.round(); i++) {
      v *= 2;
    }
    return v;
  }
}

/// The centred zone circle with the office pin and radius label.
class _ZonePreview extends StatelessWidget {
  const _ZonePreview({
    required this.radius,
    required this.metersPerPixel,
    required this.colors,
  });

  final double radius;
  final double? metersPerPixel;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    final size = metersPerPixel == null
        ? 120.0
        : (2 * radius / metersPerPixel!).clamp(40.0, 600.0);
    return SizedBox(
      width: size + 80,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.brand.withValues(alpha: 0.12),
              border: Border.all(color: colors.brand, width: 2),
            ),
          ),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: colors.brand,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: AppShadows.raised,
            ),
            child: const Icon(
              Icons.business_rounded,
              size: 16,
              color: Colors.white,
            ),
          ),
          Positioned(
            left: size / 2 + 40 + size * 0.18,
            top: size * 0.12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(999),
                boxShadow: AppShadows.raised,
              ),
              child: Text(
                '${radius.round()} m',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
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
      elevation: 1,
      shadowColor: Colors.black26,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onTap,
        icon: Icon(icon, color: color ?? colors.textPrimary),
      ),
    );
  }
}
