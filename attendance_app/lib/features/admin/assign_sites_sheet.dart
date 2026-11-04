import 'package:flutter/material.dart';

import 'package:attendance_app/core/theme/app_colors.dart';
import 'package:attendance_app/core/theme/app_spacing.dart';
import 'package:attendance_app/core/widgets/app_button.dart';
import 'package:attendance_app/data/models/location_model.dart';
import 'package:attendance_app/features/admin/locations_screen.dart';

/// Maximum sites one employee can be assigned (Security Rules enforce it too).
const maxSitesPerEmployee = 10;

/// Picks which sites an employee may punch at and which one is primary.
/// Returns null when dismissed.
Future<({List<String> ids, String? primaryId})?> showAssignSitesSheet(
  BuildContext context, {
  required List<LocationModel> sites,
  required List<String> selected,
  String? primaryId,
}) {
  return showModalBottomSheet<({List<String> ids, String? primaryId})>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _AssignSitesSheet(
      sites: sites,
      selected: selected,
      primaryId: primaryId,
    ),
  );
}

class _AssignSitesSheet extends StatefulWidget {
  const _AssignSitesSheet({
    required this.sites,
    required this.selected,
    this.primaryId,
  });

  final List<LocationModel> sites;
  final List<String> selected;
  final String? primaryId;

  @override
  State<_AssignSitesSheet> createState() => _AssignSitesSheetState();
}

class _AssignSitesSheetState extends State<_AssignSitesSheet> {
  late final List<LocationModel> _sites = [...widget.sites];
  late final List<String> _ids = widget.selected
      .where((id) => widget.sites.any((s) => s.id == id))
      .toList();
  late String? _primary = _ids.contains(widget.primaryId)
      ? widget.primaryId
      : _ids.firstOrNull;

  void _toggle(LocationModel site) {
    setState(() {
      if (_ids.remove(site.id)) {
        if (_primary == site.id) _primary = _ids.firstOrNull;
      } else if (_ids.length < maxSitesPerEmployee) {
        _ids.add(site.id);
        _primary ??= site.id;
      }
    });
  }

  Future<void> _addNew() async {
    final created = await openLocationEditor(context, sites: _sites);
    if (created == null || !mounted) return;
    setState(() {
      _sites.add(created);
      if (_ids.length < maxSitesPerEmployee) {
        _ids.add(created.id);
        _primary ??= created.id;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Work locations',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'They can punch in at any ticked location. The starred '
                    'one is their primary.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final s in _sites)
                    ListTile(
                      contentPadding: const EdgeInsets.only(
                        left: AppSpacing.md,
                        right: AppSpacing.sm,
                      ),
                      leading: Checkbox(
                        value: _ids.contains(s.id),
                        onChanged: (_) => _toggle(s),
                      ),
                      title: Text(
                        s.name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        [
                          if (s.isMain) 'Main',
                          '${s.radius.round()} m zone',
                        ].join(' · '),
                      ),
                      onTap: () => _toggle(s),
                      trailing: _ids.contains(s.id)
                          ? IconButton(
                              tooltip: 'Make primary',
                              onPressed: () => setState(() => _primary = s.id),
                              icon: Icon(
                                _primary == s.id
                                    ? Icons.star_rounded
                                    : Icons.star_outline_rounded,
                                color: _primary == s.id
                                    ? colors.brand
                                    : colors.textTertiary,
                              ),
                            )
                          : null,
                    ),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xl,
                    ),
                    leading: Icon(Icons.add_rounded, color: colors.brand),
                    title: Text(
                      'New location',
                      style: TextStyle(
                        color: colors.brand,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onTap: _addNew,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.md,
                AppSpacing.xl,
                AppSpacing.lg,
              ),
              child: AppButton(
                label: _ids.isEmpty
                    ? (widget.selected.isEmpty
                          ? 'Done'
                          : 'Remove all locations')
                    : 'Assign ${_ids.length} '
                          '${_ids.length == 1 ? 'location' : 'locations'}',
                onPressed: () => Navigator.pop(context, (
                  ids: [..._ids],
                  primaryId: _primary,
                )),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
