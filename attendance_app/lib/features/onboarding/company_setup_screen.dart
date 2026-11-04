import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:attendance_app/core/di/injection.dart';
import 'package:attendance_app/core/error/app_exception.dart';
import 'package:attendance_app/core/theme/app_colors.dart';
import 'package:attendance_app/core/theme/app_spacing.dart';
import 'package:attendance_app/core/utils/attendance_clock.dart';
import 'package:attendance_app/core/widgets/app_button.dart';
import 'package:attendance_app/core/widgets/app_card.dart';
import 'package:attendance_app/core/widgets/app_chip.dart';
import 'package:attendance_app/core/widgets/entity_tile.dart';
import 'package:attendance_app/domain/repositories/auth_repository.dart';
import 'package:attendance_app/domain/repositories/onboarding_repository.dart';
import 'package:attendance_app/features/admin/work_location_picker.dart';
import 'package:attendance_app/features/shared/user_provider.dart';

/// Step 2 of company signup: the company, its main location and default
/// hours. Shown whenever an email account has no company yet.
class CompanySetupScreen extends StatefulWidget {
  const CompanySetupScreen({super.key});

  @override
  State<CompanySetupScreen> createState() => _CompanySetupScreenState();
}

class _CompanySetupScreenState extends State<CompanySetupScreen> {
  static const _sizes = ['1–10', '11–50', '51–200', '200+'];

  final _form = GlobalKey<FormState>();
  final _adminName = TextEditingController(
    text: sl<AuthRepository>().currentUser?.displayName ?? '',
  );
  final _company = TextEditingController();
  String? _teamSize;
  Map<String, dynamic>? _zone;
  String _start = '09:00';
  String _end = '18:00';
  bool _loading = false;

  @override
  void dispose() {
    _adminName.dispose();
    _company.dispose();
    super.dispose();
  }

  Future<void> _pickZone() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => WorkLocationPicker(
          initialLat: (_zone?['latitude'] as num?)?.toDouble(),
          initialLng: (_zone?['longitude'] as num?)?.toDouble(),
          initialRadius: (_zone?['radius'] as num?)?.toDouble() ?? 100,
        ),
      ),
    );
    if (result != null) setState(() => _zone = result);
  }

  Future<void> _pickTime(bool start) async {
    final current = AttendanceClock.parseMinutes(start ? _start : _end)!;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60),
    );
    if (picked == null) return;
    final value =
        '${picked.hour.toString().padLeft(2, '0')}:'
        '${picked.minute.toString().padLeft(2, '0')}';
    setState(() => start ? _start = value : _end = value);
  }

  void _snack(String message) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), backgroundColor: context.colors.danger),
  );

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final zone = _zone;
    if (zone == null) return _snack('Place your main location on the map');
    if (_start.compareTo(_end) >= 0) {
      return _snack('The day must end after it starts');
    }
    setState(() => _loading = true);
    try {
      await sl<OnboardingRepository>().registerCompany(
        companyName: _company.text,
        adminName: _adminName.text,
        teamSize: _teamSize,
        shiftStart: _start,
        shiftEnd: _end,
        location: {
          'name': 'Head office',
          'address': zone['address'],
          'latitude': zone['latitude'],
          'longitude': zone['longitude'],
          'radius': zone['radius'],
        },
      );
      if (mounted) {
        await Provider.of<UserProvider>(
          context,
          listen: false,
        ).completeOnboarding();
      }
    } catch (e) {
      if (mounted) {
        _snack(e is AppException ? e.message : 'Couldn’t create the company');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = context.colors;
    final zone = _zone;
    const fmt = AttendanceClock.formatShiftTime;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Step 2 of 2'),
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: () =>
                Provider.of<UserProvider>(context, listen: false).signOut(),
            child: const Text('Sign out'),
          ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            children: [
              Text(
                'Set up your company',
                style: text.displaySmall?.copyWith(fontSize: 26),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'You can add more locations and change hours later.',
                style: text.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.xxl),
              TextFormField(
                controller: _company,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Company name'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _adminName,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Your name'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: AppSpacing.xl),
              Text('Team size', style: text.labelLarge),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final s in _sizes)
                    AppChip(
                      label: s,
                      selected: _teamSize == s,
                      onTap: () => setState(() => _teamSize = s),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              Text('Main location', style: text.labelLarge),
              const SizedBox(height: AppSpacing.sm),
              EntityTile(
                leading: IconChip(
                  icon: zone == null
                      ? Icons.add_location_alt_outlined
                      : Icons.business_rounded,
                ),
                title: zone == null
                    ? 'Place it on the map'
                    : (zone['address'] as String?) ?? 'Pinned point',
                subtitle: zone == null
                    ? 'Where your team punches in'
                    : '${(zone['radius'] as num).round()} m punch-in zone',
                chevron: true,
                onTap: _pickZone,
              ),
              const SizedBox(height: AppSpacing.xl),
              Text('Working hours', style: text.labelLarge),
              const SizedBox(height: AppSpacing.sm),
              AppGroup(
                children: [
                  EntityTile(
                    inGroup: true,
                    leading: const IconChip(icon: Icons.login_rounded),
                    title: 'Starts',
                    trailing: Text(
                      fmt(_start),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: colors.brand,
                      ),
                    ),
                    onTap: () => _pickTime(true),
                  ),
                  EntityTile(
                    inGroup: true,
                    leading: const IconChip(icon: Icons.logout_rounded),
                    title: 'Ends',
                    trailing: Text(
                      fmt(_end),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: colors.brand,
                      ),
                    ),
                    onTap: () => _pickTime(false),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xxl),
              AppButton(
                label: 'Create company',
                loading: _loading,
                onPressed: _loading ? null : _submit,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Free for 14 days. No card needed.',
                textAlign: TextAlign.center,
                style: text.labelSmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
