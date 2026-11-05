import 'dart:async';
import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import 'package:attendance_app/core/di/injection.dart';
import 'package:attendance_app/core/error/app_exception.dart';
import 'package:attendance_app/core/theme/app_colors.dart';
import 'package:attendance_app/core/theme/app_spacing.dart';
import 'package:attendance_app/core/utils/attendance_clock.dart';
import 'package:attendance_app/core/widgets/app_button.dart';
import 'package:attendance_app/core/widgets/app_card.dart';
import 'package:attendance_app/core/widgets/app_chip.dart';
import 'package:attendance_app/core/widgets/app_page.dart';
import 'package:attendance_app/domain/repositories/auth_repository.dart';
import 'package:attendance_app/domain/repositories/company_repository.dart';
import 'package:attendance_app/domain/repositories/onboarding_repository.dart';
import 'package:attendance_app/features/admin/work_location_picker.dart';
import 'package:attendance_app/features/onboarding/onboarding_step.dart';
import 'package:attendance_app/features/shared/user_provider.dart';

/// Industries offered at signup and on the company profile.
const companyIndustries = [
  'Logistics & transport',
  'Retail & stores',
  'Manufacturing',
  'Construction & real estate',
  'Security services',
  'Facility management',
  'Healthcare',
  'Hospitality & restaurants',
  'IT & services',
  'Education',
  'Other',
];

/// Company signup steps 2–5 (designs 1.3–1.7): verify email, company
/// details, work locations, and default hours & policy. Shown whenever an
/// email account has no company yet, so it resumes after a restart.
class CompanySetupScreen extends StatefulWidget {
  const CompanySetupScreen({super.key});

  @override
  State<CompanySetupScreen> createState() => _CompanySetupScreenState();
}

class _CompanySetupScreenState extends State<CompanySetupScreen> {
  static const industries = companyIndustries;
  static const teamSizes = ['1–5', '6–25', '26–100', '100+'];
  static const lateOptions = [5, 10, 15, 30];

  final _auth = sl<AuthRepository>();
  late int _step = (_auth.currentUser?.emailVerified ?? false) ? 3 : 2;

  // Step 3
  final _company = TextEditingController();
  final _gstin = TextEditingController();
  String? _industry;
  String? _teamSize;
  Uint8List? _logo;

  // Step 4
  final List<Map<String, dynamic>> _sites = [];

  // Step 5
  String _start = '09:00';
  String _end = '18:00';
  final Set<int> _days = {1, 2, 3, 4, 5, 6};
  int _lateAfter = 15;
  bool _checkoutInZone = true;
  bool _reminders = true;
  bool _selfie = false;

  bool _busy = false;
  int _resendIn = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _company.dispose();
    _gstin.dispose();
    super.dispose();
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: context.colors.danger),
    );
  }

  void _back() {
    if (_step <= 3 && (_auth.currentUser?.emailVerified ?? false) ||
        _step == 2) {
      // Leaving setup: sign out of the half-made account.
      Provider.of<UserProvider>(context, listen: false).signOut();
      return;
    }
    setState(() => _step--);
  }

  // ── Step 2 ────────────────────────────────────────────────────────────────

  Future<void> _checkVerified() async {
    setState(() => _busy = true);
    try {
      await _auth.currentUser?.reload();
      if (_auth.currentUser?.emailVerified ?? false) {
        setState(() => _step = 3);
      } else {
        _snack('Not verified yet. Tap the link in the email, then try again.');
      }
    } catch (e) {
      _snack('Couldn’t check. Try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    try {
      await _auth.currentUser?.sendEmailVerification();
      setState(() => _resendIn = 45);
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) return t.cancel();
        setState(() => _resendIn--);
        if (_resendIn <= 0) t.cancel();
      });
    } catch (_) {
      _snack('Couldn’t send the email. Try again in a minute.');
    }
  }

  // ── Step 3 ────────────────────────────────────────────────────────────────

  Future<void> _pickLogo() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() => _logo = bytes);
  }

  void _toLocations() {
    if (_company.text.trim().isEmpty) return _snack('Enter your company name');
    final gst = _gstin.text.trim().toUpperCase();
    if (gst.isNotEmpty && !RegExp(r'^[0-9]{2}[A-Z0-9]{13}$').hasMatch(gst)) {
      return _snack('That GSTIN doesn’t look right — it has 15 characters');
    }
    setState(() => _step = 4);
  }

  // ── Step 4 ────────────────────────────────────────────────────────────────

  Future<void> _addSite([int? editing]) async {
    final current = editing == null ? null : _sites[editing];
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => WorkLocationPicker(
          stepLabel: 'Step 4 of 5',
          initialName:
              current?['name'] as String? ??
              (_sites.isEmpty ? 'Head office' : null),
          initialLat: (current?['latitude'] as num?)?.toDouble(),
          initialLng: (current?['longitude'] as num?)?.toDouble(),
          initialRadius: (current?['radius'] as num?)?.toDouble() ?? 100,
        ),
      ),
    );
    if (result == null || !mounted) return;
    final name = (result['name'] as String).toLowerCase();
    final clash = _sites.indexWhere(
      (s) => (s['name'] as String).toLowerCase() == name,
    );
    if (clash != -1 && clash != editing) {
      return _snack('You already have a location with that name');
    }
    setState(() {
      if (editing == null) {
        _sites.add(result);
      } else {
        _sites[editing] = result;
      }
    });
  }

  // ── Step 5 ────────────────────────────────────────────────────────────────

  Future<void> _pickTime(bool start) async {
    final m = AttendanceClock.parseMinutes(start ? _start : _end)!;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: m ~/ 60, minute: m % 60),
    );
    if (picked == null) return;
    final v =
        '${picked.hour.toString().padLeft(2, '0')}:'
        '${picked.minute.toString().padLeft(2, '0')}';
    setState(() => start ? _start = v : _end = v);
  }

  Future<void> _finish() async {
    if (_start.compareTo(_end) >= 0) {
      return _snack('The day must end after it starts');
    }
    if (_days.isEmpty) return _snack('Pick at least one working day');
    final prov = Provider.of<UserProvider>(context, listen: false);
    setState(() => _busy = true);
    try {
      final user = _auth.currentUser;
      final companyId = await sl<OnboardingRepository>().registerCompany(
        companyName: _company.text,
        adminName: user?.displayName ?? user?.email?.split('@').first ?? '',
        locations: _sites,
        shiftStart: _start,
        shiftEnd: _end,
        teamSize: _teamSize,
        industry: _industry,
        gstin: _gstin.text.trim().isEmpty
            ? null
            : _gstin.text.trim().toUpperCase(),
        workingDays: _days.toList()..sort(),
        lateAfterMinutes: _lateAfter,
        checkoutInZone: _checkoutInZone,
        shiftReminders: _reminders,
        selfieRequired: _selfie,
      );
      if (_logo != null) {
        // Best effort: the company works without a logo.
        try {
          final path = 'logos/$companyId/logo.png';
          await FirebaseStorage.instance
              .ref(path)
              .putData(_logo!, SettableMetadata(contentType: 'image/png'));
          await sl<CompanyRepository>().updateProfile(companyId, {
            'logoUrl': path,
          });
        } catch (_) {}
      }
      prov.startPostSetupTour();
      await prov.completeOnboarding();
    } catch (e) {
      _snack(e is AppException ? e.message : 'Couldn’t create the company');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => switch (_step) {
    2 => _verifyStep(context),
    3 => _detailsStep(context),
    4 => _locationsStep(context),
    _ => _policyStep(context),
  };

  Widget _verifyStep(BuildContext context) {
    final colors = context.colors;
    final email = _auth.currentUser?.email ?? 'your email';
    return OnboardingStep(
      step: 2,
      of: 5,
      onBack: _back,
      leading: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: colors.brandSoft,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Icon(Icons.mail_outline_rounded, color: colors.brand, size: 28),
      ),
      title: 'Check your email',
      subtitle: Text.rich(
        TextSpan(
          text: 'Tap the link we sent to ',
          children: [
            TextSpan(
              text: email,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
            const TextSpan(text: ', then come back here.'),
          ],
        ),
      ),
      content: [
        Row(
          children: [
            Text(
              'Didn’t get it?',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            TextButton(
              onPressed: _resendIn > 0 ? null : _resend,
              child: Text(
                _resendIn > 0
                    ? 'Resend in 0:${_resendIn.toString().padLeft(2, '0')}'
                    : 'Resend link',
              ),
            ),
          ],
        ),
      ],
      footer: [
        AppButton(
          label: 'I’ve verified — continue',
          loading: _busy,
          onPressed: _busy ? null : _checkVerified,
        ),
        AppButton(
          label: 'Use a different email',
          variant: AppButtonVariant.ghost,
          onPressed: () =>
              Provider.of<UserProvider>(context, listen: false).signOut(),
        ),
      ],
    );
  }

  Widget _detailsStep(BuildContext context) {
    final colors = context.colors;
    return OnboardingStep(
      step: 3,
      of: 5,
      onBack: _back,
      title: 'About your company',
      content: [
        Row(
          children: [
            GestureDetector(
              onTap: _pickLogo,
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: colors.surfaceMuted,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: colors.borderStrong, width: 1.5),
                ),
                clipBehavior: Clip.antiAlias,
                child: _logo == null
                    ? Icon(Icons.image_outlined, color: colors.textSecondary)
                    : Image.memory(_logo!, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Company logo',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                Row(
                  children: [
                    GestureDetector(
                      onTap: _pickLogo,
                      child: Text(
                        _logo == null ? 'Upload' : 'Change',
                        style: TextStyle(
                          color: colors.brand,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Text(
                      ' · optional, PNG or JPG',
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.textTertiary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        const FieldLabel('Company name'),
        TextField(
          controller: _company,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            hintText: 'Bright Logistics Pvt Ltd',
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        const FieldLabel('Industry'),
        DropdownButtonFormField<String>(
          initialValue: _industry,
          hint: const Text('Choose one'),
          items: [
            for (final i in industries)
              DropdownMenuItem(value: i, child: Text(i)),
          ],
          onChanged: (v) => setState(() => _industry = v),
        ),
        const SizedBox(height: AppSpacing.lg),
        const FieldLabel('How many people will use PunchIn?'),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final s in teamSizes)
              AppChip(
                label: s,
                selected: _teamSize == s,
                onTap: () => setState(() => _teamSize = s),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        const FieldLabel('GSTIN', optional: '(optional, for invoices)'),
        TextField(
          controller: _gstin,
          textCapitalization: TextCapitalization.characters,
          maxLength: 15,
          decoration: const InputDecoration(
            hintText: '29ABCDE1234F1Z5',
            counterText: '',
          ),
        ),
      ],
      footer: [AppButton(label: 'Continue', onPressed: _toLocations)],
    );
  }

  Widget _locationsStep(BuildContext context) {
    final colors = context.colors;
    return OnboardingStep(
      step: 4,
      of: 5,
      white: false,
      footerDivider: true,
      onBack: _back,
      title: 'Your work locations',
      subtitle: const Text(
        'Add every place your team works. You’ll choose which people punch '
        'in where.',
      ),
      content: [
        if (_sites.isNotEmpty) ...[
          AppGroup(
            children: [
              for (var i = 0; i < _sites.length; i++)
                InkWell(
                  onTap: () => _addSite(i),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: colors.brandSoft,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          child: Center(
                            child: Container(
                              width: 26,
                              height: 26,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: colors.brand,
                                  width: 2,
                                ),
                                color: colors.brand.withValues(alpha: 0.15),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _sites[i]['name'] as String,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                [
                                  if ((_sites[i]['address'] as String?)
                                          ?.isNotEmpty ??
                                      false)
                                    _sites[i]['address'] as String,
                                  '${(_sites[i]['radius'] as num).round()} m',
                                ].join(' · '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        if (i == 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: colors.brandSoft,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'Main',
                              style: TextStyle(
                                color: colors.brandStrong,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                        else
                          IconButton(
                            tooltip: 'Remove',
                            icon: Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: colors.textTertiary,
                            ),
                            onPressed: () => setState(() => _sites.removeAt(i)),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        AppButton(
          label: _sites.isEmpty
              ? 'Add your first location'
              : 'Add another location',
          icon: Icons.add_rounded,
          variant: AppButtonVariant.secondary,
          onPressed: _addSite,
        ),
        const SizedBox(height: AppSpacing.md),
        const AppBanner(
          icon: Icons.info_outline_rounded,
          child: Text(
            'Unlimited locations on every plan. An employee can be assigned '
            'to one site or several — the app uses whichever they’re '
            'nearest to.',
          ),
        ),
      ],
      footer: [
        AppButton(
          label: 'Continue',
          onPressed: _sites.isEmpty
              ? () => _snack('Add at least one location')
              : () => setState(() => _step = 5),
        ),
      ],
    );
  }

  Widget _policyStep(BuildContext context) {
    final colors = context.colors;
    const fmt = AttendanceClock.formatShiftTime;
    const dayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    Widget timeBox(String label, String value, VoidCallback onTap) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FieldLabel(label),
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Container(
              height: 48,
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: colors.border),
              ),
              child: Text(
                fmt(value),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );

    Widget toggle(
      String title,
      String subtitle,
      bool value,
      ValueChanged<bool> onChanged, {
      String? badge,
    }) => SwitchListTile(
      value: value,
      onChanged: onChanged,
      title: Row(
        children: [
          Flexible(
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
          ),
          if (badge != null) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: colors.brandSoft,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                badge,
                style: TextStyle(
                  color: colors.brandStrong,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 13)),
    );

    return OnboardingStep(
      step: 5,
      of: 5,
      white: false,
      footerDivider: true,
      onBack: _back,
      title: 'Default work hours',
      subtitle: const Text(
        'You can change these for any person or location later.',
      ),
      content: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  timeBox('Starts', _start, () => _pickTime(true)),
                  const SizedBox(width: 12),
                  timeBox('Ends', _end, () => _pickTime(false)),
                ],
              ),
              const SizedBox(height: 14),
              const FieldLabel('Working days'),
              Row(
                children: [
                  for (var d = 1; d <= 7; d++) ...[
                    if (d > 1) const SizedBox(width: 6),
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: () => setState(
                          () => _days.contains(d)
                              ? _days.remove(d)
                              : _days.add(d),
                        ),
                        child: Container(
                          height: 36,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _days.contains(d)
                                ? colors.brandSoft
                                : colors.surface,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: _days.contains(d)
                                  ? colors.brand
                                  : colors.border,
                            ),
                          ),
                          child: Text(
                            dayLetters[d - 1],
                            style: TextStyle(
                              fontWeight: _days.contains(d)
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              color: _days.contains(d)
                                  ? colors.brandStrong
                                  : colors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 14),
              const FieldLabel('Mark late after'),
              AppSegmented<int>(
                selected: _lateAfter,
                onChanged: (v) => setState(() => _lateAfter = v),
                segments: {for (final m in lateOptions) m: '$m min'},
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        AppGroup(
          children: [
            toggle(
              'Check-out inside the zone',
              'Stops people punching out from home',
              _checkoutInZone,
              (v) => setState(() => _checkoutInZone = v),
            ),
            toggle(
              'Shift reminders',
              'Notify before start and if they forget to check out',
              _reminders,
              (v) => setState(() => _reminders = v),
            ),
            toggle(
              'Selfie on check-in',
              'Free to try during your trial',
              _selfie,
              (v) => setState(() => _selfie = v),
              badge: 'Business',
            ),
          ],
        ),
      ],
      footer: [
        AppButton(
          label: 'Finish setup',
          loading: _busy,
          onPressed: _busy ? null : _finish,
        ),
      ],
    );
  }
}
