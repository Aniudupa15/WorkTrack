import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import 'package:attendance_app/core/constants/app_constants.dart';
import 'package:attendance_app/core/di/injection.dart';
import 'package:attendance_app/core/error/app_exception.dart';
import 'package:attendance_app/core/theme/app_colors.dart';
import 'package:attendance_app/core/theme/app_spacing.dart';
import 'package:attendance_app/core/widgets/app_button.dart';
import 'package:attendance_app/core/widgets/app_card.dart';
import 'package:attendance_app/core/widgets/app_loader.dart';
import 'package:attendance_app/core/widgets/empty_state.dart';
import 'package:attendance_app/core/widgets/entity_tile.dart';
import 'package:attendance_app/data/models/location_model.dart';
import 'package:attendance_app/data/models/user_model.dart';
import 'package:attendance_app/domain/repositories/employee_repository.dart';
import 'package:attendance_app/domain/repositories/location_repository.dart';
import 'package:attendance_app/features/admin/work_location_picker.dart';
import 'package:attendance_app/features/shared/user_provider.dart';

/// The company's work sites with how many people are assigned to each.
class LocationsScreen extends StatelessWidget {
  const LocationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final companyId = Provider.of<UserProvider>(context).company?.id ?? '';
    final colors = context.colors;

    return StreamBuilder<List<LocationModel>>(
      stream: sl<LocationRepository>().watchLocations(companyId),
      builder: (context, snap) {
        final sites = snap.data ?? const <LocationModel>[];
        Future<void> add() => openLocationEditor(context, sites: sites);
        return Scaffold(
          appBar: AppBar(
            title: const Text('Locations'),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.md),
                child: AppButton(
                  label: 'Add',
                  size: AppButtonSize.small,
                  expand: false,
                  onPressed: add,
                ),
              ),
            ],
          ),
          body: snap.connectionState == ConnectionState.waiting
              ? const AppLoader()
              : sites.isEmpty
              ? EmptyState(
                  icon: Icons.add_location_alt_outlined,
                  title: 'No locations yet',
                  subtitle:
                      'Add your office, warehouse or client sites. Each one '
                      'has its own punch-in zone.',
                  action: FilledButton.tonalIcon(
                    onPressed: add,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Add location'),
                  ),
                )
              : StreamBuilder<List<UserModel>>(
                  stream: sl<EmployeeRepository>().watchEmployees(companyId),
                  builder: (context, empSnap) {
                    final people = empSnap.data ?? const <UserModel>[];
                    int count(String id) =>
                        people.where((e) => e.locationIds.contains(id)).length;
                    return ListView(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.sm,
                        AppSpacing.lg,
                        AppSpacing.xxl,
                      ),
                      children: [
                        AppGroup(
                          children: [
                            for (final s in sites)
                              EntityTile(
                                inGroup: true,
                                leading: IconChip(
                                  icon: s.isMain
                                      ? Icons.business_rounded
                                      : Icons.location_on_outlined,
                                ),
                                title: s.isMain ? '${s.name} · Main' : s.name,
                                subtitle: [
                                  '${count(s.id)} '
                                      '${count(s.id) == 1 ? 'person' : 'people'}',
                                  '${s.radius.round()} m zone',
                                  if ((s.address ?? '').isNotEmpty) s.address!,
                                ].join(' · '),
                                chevron: true,
                                onTap: () => openLocationEditor(
                                  context,
                                  sites: sites,
                                  site: s,
                                  assigned: count(s.id),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'Employees can punch in at any location assigned '
                          'to them. Assign locations from each person’s '
                          'profile in Team.',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colors.textTertiary),
                        ),
                      ],
                    );
                  },
                ),
        );
      },
    );
  }
}

/// Opens the add / edit form and returns the saved site, or null.
Future<LocationModel?> openLocationEditor(
  BuildContext context, {
  required List<LocationModel> sites,
  LocationModel? site,
  int assigned = 0,
}) {
  return Navigator.push<LocationModel>(
    context,
    MaterialPageRoute(
      builder: (_) =>
          LocationEditor(sites: sites, site: site, assigned: assigned),
    ),
  );
}

class LocationEditor extends StatefulWidget {
  const LocationEditor({
    super.key,
    required this.sites,
    this.site,
    this.assigned = 0,
  });

  final List<LocationModel> sites;
  final LocationModel? site;

  /// How many employees are assigned to [site]; a site in use can't be deleted.
  final int assigned;

  @override
  State<LocationEditor> createState() => _LocationEditorState();
}

class _LocationEditorState extends State<LocationEditor> {
  final _name = TextEditingController();
  Map<String, dynamic>? _zone;
  late bool _isMain;
  bool _saving = false;

  bool get _isEdit => widget.site != null;

  @override
  void initState() {
    super.initState();
    final s = widget.site;
    _name.text = s?.name ?? (widget.sites.isEmpty ? 'Head office' : '');
    _zone = s?.toZone();
    // The first site is always the main one.
    _isMain = s?.isMain ?? widget.sites.isEmpty;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  String get _companyId =>
      Provider.of<UserProvider>(context, listen: false).company?.id ?? '';

  Future<void> _pick() async {
    final defaultRadius =
        Provider.of<UserProvider>(
          context,
          listen: false,
        ).company?.defaultRadius ??
        AppConstants.defaultGeofenceRadiusMeters;
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => WorkLocationPicker(
          initialLat: (_zone?['latitude'] as num?)?.toDouble(),
          initialLng: (_zone?['longitude'] as num?)?.toDouble(),
          initialRadius:
              (_zone?['radius'] as num?)?.toDouble() ?? defaultRadius,
        ),
      ),
    );
    if (result != null) setState(() => _zone = result);
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final zone = _zone;
    if (name.isEmpty || zone == null) {
      _snack(name.isEmpty ? 'Give the location a name' : 'Place it on the map');
      return;
    }
    final taken = widget.sites.any(
      (s) =>
          s.id != widget.site?.id && s.name.toLowerCase() == name.toLowerCase(),
    );
    if (taken) {
      _snack('You already have a location called $name');
      return;
    }
    setState(() => _saving = true);
    try {
      final draft = LocationModel(
        id: widget.site?.id ?? '',
        name: name,
        address: zone['address'] as String?,
        latitude: (zone['latitude'] as num).toDouble(),
        longitude: (zone['longitude'] as num).toDouble(),
        radius: (zone['radius'] as num).toDouble(),
        isMain: _isMain,
      );
      final id = await sl<LocationRepository>().saveLocation(
        _companyId,
        draft,
        sites: widget.sites,
      );
      if (mounted) {
        Navigator.pop(
          context,
          LocationModel(
            id: id,
            name: draft.name,
            address: draft.address,
            latitude: draft.latitude,
            longitude: draft.longitude,
            radius: draft.radius,
            isMain: draft.isMain,
          ),
        );
      }
    } catch (e) {
      _snack(e is AppException ? e.message : 'Couldn’t save the location');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final site = widget.site!;
    if (widget.assigned > 0) {
      _snack(
        'Move the ${widget.assigned} '
        '${widget.assigned == 1 ? 'person' : 'people'} at ${site.name} to '
        'another location first',
      );
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${site.name}?'),
        content: const Text(
          'Past attendance at this location is kept. This can’t be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Delete',
              style: TextStyle(color: context.colors.danger),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await sl<LocationRepository>().deleteLocation(_companyId, site.id);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _snack(e is AppException ? e.message : 'Couldn’t delete the location');
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final zone = _zone;
    final point = zone == null
        ? null
        : LatLng(
            (zone['latitude'] as num).toDouble(),
            (zone['longitude'] as num).toDouble(),
          );
    // The only main site can't be demoted; promote another one instead.
    final lockMain = widget.site?.isMain == true || widget.sites.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit location' : 'New location'),
        actions: [
          if (_isEdit && !widget.site!.isMain)
            IconButton(
              tooltip: 'Delete',
              icon: Icon(Icons.delete_outline_rounded, color: colors.danger),
              onPressed: _delete,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            maxLength: 100,
            decoration: const InputDecoration(
              labelText: 'Name',
              hintText: 'e.g. Head office, Whitefield warehouse',
              counterText: '',
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          GestureDetector(
            onTap: _pick,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              child: Container(
                height: 180,
                decoration: BoxDecoration(
                  color: colors.surfaceMuted,
                  border: Border.all(color: colors.border),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: point == null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.add_location_alt_outlined,
                              color: colors.brand,
                              size: 28,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              'Place on map',
                              style: TextStyle(
                                color: colors.brand,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      )
                    : IgnorePointer(
                        child: FlutterMap(
                          key: ValueKey(point),
                          options: MapOptions(
                            initialCenter: point,
                            initialZoom: 16,
                          ),
                          children: [
                            TileLayer(
                              urlTemplate: AppConstants.osmTileUrl,
                              userAgentPackageName: AppConstants.packageName,
                            ),
                            CircleLayer(
                              circles: [
                                CircleMarker(
                                  point: point,
                                  useRadiusInMeter: true,
                                  radius: (zone!['radius'] as num).toDouble(),
                                  color: colors.brand.withValues(alpha: 0.15),
                                  borderColor: colors.brand,
                                  borderStrokeWidth: 2,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
              ),
            ),
          ),
          if (zone != null) ...[
            const SizedBox(height: AppSpacing.md),
            AppGroup(
              children: [
                EntityTile(
                  inGroup: true,
                  leading: const IconChip(icon: Icons.place_outlined),
                  title: (zone['address'] as String?)?.isNotEmpty == true
                      ? zone['address'] as String
                      : 'Pinned point',
                  subtitle:
                      '${(zone['radius'] as num).round()} m punch-in zone',
                  trailing: TextButton(
                    onPressed: _pick,
                    child: const Text('Change'),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          AppGroup(
            children: [
              SwitchListTile(
                value: _isMain,
                onChanged: lockMain ? null : (v) => setState(() => _isMain = v),
                title: const Text('Main location'),
                subtitle: const Text('Your headquarters, listed first'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            label: _isEdit ? 'Save changes' : 'Add location',
            loading: _saving,
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
    );
  }
}
