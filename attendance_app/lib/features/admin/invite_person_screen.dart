import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:attendance_app/core/di/injection.dart';
import 'package:attendance_app/core/error/app_exception.dart';
import 'package:attendance_app/core/theme/app_colors.dart';
import 'package:attendance_app/core/theme/app_spacing.dart';
import 'package:attendance_app/core/widgets/app_button.dart';
import 'package:attendance_app/core/widgets/entity_tile.dart';
import 'package:attendance_app/data/models/location_model.dart';
import 'package:attendance_app/domain/repositories/location_repository.dart';
import 'package:attendance_app/domain/repositories/onboarding_repository.dart';
import 'package:attendance_app/features/admin/assign_sites_sheet.dart';
import 'package:attendance_app/features/onboarding/phone_sign_in_screen.dart';
import 'package:attendance_app/features/shared/user_provider.dart';

/// Invites one person by phone with their department and work locations.
/// They join by signing in with that number.
class InvitePersonScreen extends StatefulWidget {
  const InvitePersonScreen({super.key});

  @override
  State<InvitePersonScreen> createState() => _InvitePersonScreenState();
}

class _InvitePersonScreenState extends State<InvitePersonScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _dept = TextEditingController();
  List<LocationModel> _sites = const [];
  List<String> _ids = [];
  String? _primary;
  bool _loading = false;

  String get _companyId =>
      Provider.of<UserProvider>(context, listen: false).company?.id ?? '';

  @override
  void initState() {
    super.initState();
    sl<LocationRepository>().getLocations(_companyId).then((sites) {
      if (!mounted) return;
      final main = sites.where((s) => s.isMain).firstOrNull;
      setState(() {
        _sites = sites;
        if (main != null) {
          _ids = [main.id];
          _primary = main.id;
        }
      });
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _dept.dispose();
    super.dispose();
  }

  Future<void> _chooseSites() async {
    final result = await showAssignSitesSheet(
      context,
      sites: _sites,
      selected: _ids,
      primaryId: _primary,
    );
    if (result == null) return;
    final sites = await sl<LocationRepository>().getLocations(_companyId);
    if (!mounted) return;
    setState(() {
      _sites = sites;
      _ids = result.ids;
      _primary = result.primaryId;
    });
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final byId = {for (final s in _sites) s.id: s.name};
    final ordered = [?_primary, ..._ids.where((id) => id != _primary)];
    setState(() => _loading = true);
    try {
      final result = await sl<OnboardingRepository>().importEmployees(
        _companyId,
        [
          {
            'name': _name.text.trim(),
            'phone': PhoneSignInScreen.toE164(_phone.text),
            if (_dept.text.trim().isNotEmpty) 'department': _dept.text.trim(),
            if (ordered.isNotEmpty)
              'location': ordered.map((id) => byId[id]).join(';'),
          },
        ],
      );
      if (!mounted) return;
      if (result.errors.isNotEmpty) {
        throw AppException(result.errors.values.first);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${_name.text.trim()} is invited. Ask them to sign in to '
            'PunchIn with ${_phone.text.trim()}.',
          ),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e is AppException ? e.message : 'Couldn’t invite'),
          backgroundColor: context.colors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final names = [
      for (final id in [?_primary, ..._ids.where((id) => id != _primary)])
        ..._sites.where((s) => s.id == id).map((s) => s.name),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Add one person')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Full name'),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]')),
              ],
              decoration: const InputDecoration(
                labelText: 'Mobile number',
                prefixText: '+91  ',
              ),
              validator: (v) => PhoneSignInScreen.toE164(v ?? '') == null
                  ? 'Enter a 10-digit mobile number'
                  : null,
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _dept,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Department (optional)',
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            EntityTile(
              leading: const IconChip(icon: Icons.location_on_outlined),
              title: names.isEmpty ? 'No location' : names.first,
              subtitle: names.length > 1
                  ? '+ ${names.skip(1).join(', ')}'
                  : 'Where they punch in',
              chevron: true,
              onTap: _chooseSites,
            ),
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: 'Send invite',
              loading: _loading,
              onPressed: _loading ? null : _submit,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'They’ll use the company’s default hours; change them from '
              'Team once they join.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }
}
