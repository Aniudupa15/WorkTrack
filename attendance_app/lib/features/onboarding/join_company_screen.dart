import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:attendance_app/core/di/injection.dart';
import 'package:attendance_app/core/error/app_exception.dart';
import 'package:attendance_app/core/theme/app_colors.dart';
import 'package:attendance_app/core/theme/app_spacing.dart';
import 'package:attendance_app/core/widgets/app_button.dart';
import 'package:attendance_app/domain/repositories/auth_repository.dart';
import 'package:attendance_app/features/onboarding/onboarding_step.dart';
import 'package:attendance_app/features/onboarding/phone_sign_in_screen.dart';
import 'package:attendance_app/features/onboarding/qr_scan_screen.dart';
import 'package:attendance_app/features/shared/user_provider.dart';

/// Design 3.1: enter (or scan) the company's invite code.
class JoinCompanyScreen extends StatefulWidget {
  const JoinCompanyScreen({super.key, this.afterSignIn = false});

  /// Already signed in by phone: skip the SMS step.
  final bool afterSignIn;

  @override
  State<JoinCompanyScreen> createState() => _JoinCompanyScreenState();
}

class _JoinCompanyScreenState extends State<JoinCompanyScreen> {
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  String get _clean => _code.text.trim().toUpperCase().replaceAll('-', '');

  void _continue({bool invited = false}) {
    if (!invited && _clean.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter the code from your manager')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EmployeeSignupScreen(
          code: invited ? null : _clean,
          afterSignIn: widget.afterSignIn,
        ),
      ),
    );
  }

  Future<void> _scan() async {
    final code = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const QrScanScreen()),
    );
    if (code == null || !mounted) return;
    _code.text = code;
    _continue();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(backgroundColor: colors.surface),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                children: [
                  const Text(
                    'Join your company',
                    style: TextStyle(
                      fontSize: 22,
                      height: 28 / 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Enter the code from your manager, or tap the link in '
                    'your invite SMS.',
                    style: text.bodyMedium?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const FieldLabel('Invite code'),
                  TextField(
                    controller: _code,
                    autofocus: true,
                    textCapitalization: TextCapitalization.characters,
                    autocorrect: false,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9-]')),
                      LengthLimitingTextInputFormatter(10),
                    ],
                    onSubmitted: (_) => _continue(),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 3,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'BRT-7K4Q',
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 16,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.shield_outlined,
                        size: 18,
                        color: colors.brand,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Your employer only sees your location at the '
                          'moment you punch in or out — never at other times.',
                          style: text.bodySmall,
                        ),
                      ),
                    ],
                  ),
                  if (!widget.afterSignIn) ...[
                    const SizedBox(height: AppSpacing.lg),
                    TextButton(
                      onPressed: () => _continue(invited: true),
                      child: const Text('My manager added my phone number'),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppButton(label: 'Continue', onPressed: _continue),
                  const SizedBox(height: AppSpacing.sm),
                  AppButton(
                    label: 'Scan a QR code instead',
                    variant: AppButtonVariant.ghost,
                    onPressed: _scan,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Design 3.2 (step 1 of 3): name, mobile, optional email and employee ID,
/// then an SMS code signs them in.
class EmployeeSignupScreen extends StatefulWidget {
  const EmployeeSignupScreen({super.key, this.code, this.afterSignIn = false});

  final bool afterSignIn;

  /// The company code, or null when joining from a phone invite.
  final String? code;

  @override
  State<EmployeeSignupScreen> createState() => _EmployeeSignupScreenState();
}

class _EmployeeSignupScreenState extends State<EmployeeSignupScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _employeeId = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _employeeId.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_form.currentState!.validate()) return;
    final prov = Provider.of<UserProvider>(context, listen: false);
    prov.pendingJoin = (
      code: widget.code,
      name: _name.text.trim(),
      email: _email.text.trim().isEmpty ? null : _email.text.trim(),
      employeeNumber: _employeeId.text.trim().isEmpty
          ? null
          : _employeeId.text.trim(),
    );
    if (widget.afterSignIn) {
      Navigator.popUntil(context, (r) => r.isFirst);
      return;
    }
    final e164 = PhoneSignInScreen.toE164(_phone.text)!;
    setState(() => _loading = true);
    try {
      final id = await sl<AuthRepository>().sendPhoneCode(e164);
      if (!mounted) return;
      if (id == null) {
        // Verified on this device already; the join screen takes over.
        Navigator.popUntil(context, (r) => r.isFirst);
        return;
      }
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PhoneSignInScreen(phone: e164, verificationId: id),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e is AppException ? e.message : 'Couldn’t send the code',
          ),
          backgroundColor: context.colors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Form(
      key: _form,
      child: OnboardingStep(
        step: 1,
        of: 3,
        onBack: () => Navigator.pop(context),
        leading: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: colors.brandSoft,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            widget.code == null
                ? 'Joining from your invite'
                : 'Joining with code ${widget.code}',
            style: TextStyle(
              color: colors.brandStrong,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
        title: 'Your details',
        content: [
          const FieldLabel('Full name'),
          TextFormField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(hintText: 'Ravi Kumar'),
            validator: (v) => widget.code != null && (v ?? '').trim().isEmpty
                ? 'Required'
                : null,
          ),
          const SizedBox(height: AppSpacing.lg),
          if (!widget.afterSignIn) ...[
            const FieldLabel('Mobile number'),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]')),
              ],
              decoration: const InputDecoration(
                prefixIcon: Padding(
                  padding: EdgeInsets.only(left: 16, right: 8),
                  child: Text('+91', style: TextStyle(fontSize: 16)),
                ),
                prefixIconConstraints: BoxConstraints(minWidth: 0),
                hintText: '99001 23456',
                helperText:
                    'We’ll text a code to sign you in — no password needed.',
                helperMaxLines: 2,
              ),
              validator: (v) => PhoneSignInScreen.toE164(v ?? '') == null
                  ? 'Enter a 10-digit mobile number'
                  : null,
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          const FieldLabel('Email', optional: '(optional)'),
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            decoration: const InputDecoration(hintText: 'ravi@company.com'),
            validator: (v) {
              final t = (v ?? '').trim();
              return t.isEmpty || RegExp(r'^\S+@\S+\.\S+$').hasMatch(t)
                  ? null
                  : 'Enter a valid email';
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          const FieldLabel('Employee ID', optional: '(optional)'),
          TextFormField(
            controller: _employeeId,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(hintText: 'BL-0142'),
          ),
        ],
        footer: [
          AppButton(
            label: widget.afterSignIn ? 'Join' : 'Send code',
            loading: _loading,
            onPressed: _loading ? null : _send,
          ),
        ],
      ),
    );
  }
}
