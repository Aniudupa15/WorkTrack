import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:attendance_app/core/di/injection.dart';
import 'package:attendance_app/core/error/app_exception.dart';
import 'package:attendance_app/core/theme/app_colors.dart';
import 'package:attendance_app/core/theme/app_spacing.dart';
import 'package:attendance_app/core/widgets/app_button.dart';
import 'package:attendance_app/core/widgets/app_loader.dart';
import 'package:attendance_app/domain/repositories/onboarding_repository.dart';
import 'package:attendance_app/features/onboarding/qr_scan_screen.dart';
import 'package:attendance_app/features/shared/user_provider.dart';

/// Shown after a phone sign-in that isn't part of a company yet. First tries
/// the admin's phone invite; without one, asks for the company code (typed or
/// scanned) and the person's name.
class JoinTeamScreen extends StatefulWidget {
  const JoinTeamScreen({super.key});

  @override
  State<JoinTeamScreen> createState() => _JoinTeamScreenState();
}

class _JoinTeamScreenState extends State<JoinTeamScreen> {
  final _form = GlobalKey<FormState>();
  final _code = TextEditingController();
  final _name = TextEditingController();
  final _repo = sl<OnboardingRepository>();
  bool _checkingInvite = true;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _tryInvite();
  }

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _tryInvite() async {
    try {
      await _repo.claimJoin();
      await _finish();
    } catch (e) {
      // No invite for this number (or offline): fall back to the code form.
      if (mounted) setState(() => _checkingInvite = false);
    }
  }

  Future<void> _finish() async {
    if (!mounted) return;
    await Provider.of<UserProvider>(
      context,
      listen: false,
    ).completeOnboarding();
  }

  Future<void> _scan() async {
    final code = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const QrScanScreen()),
    );
    if (code != null) setState(() => _code.text = code);
  }

  Future<void> _join() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await _repo.claimJoin(code: _code.text, name: _name.text);
      await _finish();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e is AppException ? e.message : 'Couldn’t join'),
          backgroundColor: context.colors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingInvite) {
      return const Scaffold(body: AppLoader());
    }
    final text = Theme.of(context).textTheme;
    final colors = context.colors;
    return Scaffold(
      appBar: AppBar(
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
                'Join your team',
                style: text.displaySmall?.copyWith(fontSize: 26),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Enter the company code from your admin, or scan the QR '
                'code on the office notice board.',
                style: text.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.xxl),
              TextFormField(
                controller: _code,
                textCapitalization: TextCapitalization.characters,
                autocorrect: false,
                style: const TextStyle(
                  fontSize: 20,
                  letterSpacing: 4,
                  fontWeight: FontWeight.w700,
                ),
                decoration: InputDecoration(
                  labelText: 'Company code',
                  hintText: 'e.g. BRT7K4',
                  suffixIcon: IconButton(
                    tooltip: 'Scan QR code',
                    icon: Icon(
                      Icons.qr_code_scanner_rounded,
                      color: colors.brand,
                    ),
                    onPressed: _scan,
                  ),
                ),
                validator: (v) =>
                    v == null || v.trim().length < 4 ? 'Enter the code' : null,
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Your full name'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: AppSpacing.xxl),
              AppButton(
                label: 'Join',
                loading: _loading,
                onPressed: _loading ? null : _join,
              ),
              const SizedBox(height: AppSpacing.lg),
              OutlinedButton.icon(
                onPressed: _scan,
                icon: const Icon(Icons.qr_code_scanner_rounded),
                label: const Text('Scan QR code'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
