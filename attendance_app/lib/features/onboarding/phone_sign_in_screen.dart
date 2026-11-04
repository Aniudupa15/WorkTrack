import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:attendance_app/core/di/injection.dart';
import 'package:attendance_app/core/error/app_exception.dart';
import 'package:attendance_app/core/theme/app_colors.dart';
import 'package:attendance_app/core/theme/app_spacing.dart';
import 'package:attendance_app/core/widgets/app_button.dart';
import 'package:attendance_app/domain/repositories/auth_repository.dart';

/// Phone sign-in for employees: number → SMS code. New numbers continue to
/// [JoinTeamScreen] (the auth state change routes there); known ones land in
/// the app.
class PhoneSignInScreen extends StatefulWidget {
  const PhoneSignInScreen({super.key, this.phone, this.verificationId});

  /// Already-sent code for [phone] (E.164): open on the code step.
  final String? phone;
  final String? verificationId;

  /// Indian numbers by default: "98450 12345" → "+919845012345". Returns null
  /// when it doesn't look like a phone number.
  static String? toE164(String input) {
    var d = input.replaceAll(RegExp(r'[\s\-().]'), '');
    if (d.startsWith('+')) {
      return RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(d) ? d : null;
    }
    if (RegExp(r'^0\d{10}$').hasMatch(d)) d = d.substring(1);
    if (RegExp(r'^[6-9]\d{9}$').hasMatch(d)) return '+91$d';
    if (RegExp(r'^91[6-9]\d{9}$').hasMatch(d)) return '+$d';
    return null;
  }

  @override
  State<PhoneSignInScreen> createState() => _PhoneSignInScreenState();
}

class _PhoneSignInScreenState extends State<PhoneSignInScreen> {
  final _phone = TextEditingController();
  final _code = TextEditingController();
  final _auth = sl<AuthRepository>();
  late String? _verificationId = widget.verificationId;
  late String? _e164 = widget.phone;
  bool _loading = false;
  int _resendIn = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  void _error(Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(e is AppException ? e.message : 'Something went wrong'),
        backgroundColor: context.colors.danger,
      ),
    );
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _resendIn = 30);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _resendIn--);
      if (_resendIn <= 0) t.cancel();
    });
  }

  Future<void> _send({bool resend = false}) async {
    final e164 = PhoneSignInScreen.toE164(_phone.text);
    if (e164 == null) {
      return _error(const AppException('Enter a 10-digit mobile number'));
    }
    setState(() => _loading = true);
    try {
      final id = await _auth.sendPhoneCode(e164, resend: resend);
      if (!mounted) return;
      if (id == null) return _done(); // Auto-verified on this device.
      setState(() {
        _verificationId = id;
        _e164 = e164;
      });
      _startTimer();
    } catch (e) {
      _error(e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verify() async {
    if (_code.text.trim().length != 6) {
      return _error(const AppException('Enter the 6-digit code'));
    }
    setState(() => _loading = true);
    try {
      await _auth.confirmPhoneCode(_verificationId!, _code.text);
      _done();
    } catch (e) {
      _error(e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _done() {
    if (mounted) Navigator.popUntil(context, (r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = context.colors;
    final codeStep = _verificationId != null;

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          children: [
            Text(
              codeStep ? 'Enter the code' : 'Your mobile number',
              style: text.displaySmall?.copyWith(fontSize: 26),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              codeStep
                  ? 'We sent a 6-digit code to $_e164.'
                  : 'We’ll text you a code to sign in. Use the number your '
                        'employer has for you.',
              style: text.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.xxl),
            if (!codeStep)
              TextField(
                controller: _phone,
                autofocus: true,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]')),
                ],
                onSubmitted: (_) => _send(),
                style: const TextStyle(fontSize: 18, letterSpacing: 0.5),
                decoration: const InputDecoration(
                  labelText: 'Mobile number',
                  prefixText: '+91  ',
                  hintText: '98450 12345',
                ),
              )
            else
              TextField(
                controller: _code,
                autofocus: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                onChanged: (v) {
                  if (v.length == 6) _verify();
                },
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(
                  fontSize: 28,
                  letterSpacing: 12,
                  fontWeight: FontWeight.w700,
                ),
                decoration: const InputDecoration(counterText: ''),
              ),
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: codeStep ? 'Verify' : 'Send code',
              loading: _loading,
              onPressed: _loading ? null : (codeStep ? _verify : _send),
            ),
            if (codeStep) ...[
              const SizedBox(height: AppSpacing.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: () => setState(() {
                      _verificationId = null;
                      _code.clear();
                    }),
                    child: const Text('Change number'),
                  ),
                  Text('·', style: TextStyle(color: colors.textTertiary)),
                  TextButton(
                    onPressed: _resendIn > 0 || _loading
                        ? null
                        : () => _send(resend: true),
                    child: Text(
                      _resendIn > 0 ? 'Resend in $_resendIn s' : 'Resend code',
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
