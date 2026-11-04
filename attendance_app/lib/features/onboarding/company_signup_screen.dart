import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:attendance_app/core/di/injection.dart';
import 'package:attendance_app/core/error/app_exception.dart';
import 'package:attendance_app/core/theme/app_colors.dart';
import 'package:attendance_app/core/theme/app_spacing.dart';
import 'package:attendance_app/core/widgets/app_button.dart';
import 'package:attendance_app/domain/repositories/auth_repository.dart';
import 'package:attendance_app/features/onboarding/onboarding_step.dart';
import 'package:attendance_app/features/shared/settings_screen.dart';

/// Company signup, step 1 of 5 (design 1.2): the admin's own account. Once it
/// exists the app routes to the remaining setup steps (also after a restart).
class CompanySignupScreen extends StatefulWidget {
  const CompanySignupScreen({super.key});

  @override
  State<CompanySignupScreen> createState() => _CompanySignupScreenState();
}

class _CompanySignupScreenState extends State<CompanySignupScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _loading = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await sl<AuthRepository>().createAdminAccount(
        name: _name.text,
        email: _email.text,
        password: _password.text,
      );
      // The auth state change takes over and shows the next step.
      if (mounted) Navigator.popUntil(context, (r) => r.isFirst);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e is AppException ? e.message : 'Couldn’t sign up'),
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
    String? required(String? v) =>
        v == null || v.trim().isEmpty ? 'Required' : null;

    return Form(
      key: _form,
      child: OnboardingStep(
        step: 1,
        of: 5,
        onBack: () => Navigator.pop(context),
        title: 'Create your account',
        subtitle: const Text(
          'You’ll manage your company, locations and billing from here.',
        ),
        content: [
          const FieldLabel('Full name'),
          TextFormField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(hintText: 'Asha Rao'),
            validator: required,
          ),
          const SizedBox(height: AppSpacing.lg),
          const FieldLabel('Work email'),
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            decoration: const InputDecoration(
              hintText: 'asha@brightlogistics.in',
            ),
            validator: (v) =>
                v == null || !RegExp(r'^\S+@\S+\.\S+$').hasMatch(v.trim())
                ? 'Enter a valid email'
                : null,
          ),
          const SizedBox(height: AppSpacing.lg),
          const FieldLabel('Password'),
          TextFormField(
            controller: _password,
            obscureText: _obscure,
            onFieldSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              helperText: '8+ characters with a number',
              suffixIcon: IconButton(
                icon: Icon(
                  _obscure
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  size: 20,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            validator: (v) =>
                v == null || v.length < 8 || !v.contains(RegExp(r'\d'))
                ? 'Use 8+ characters with a number'
                : null,
          ),
        ],
        footer: [
          AppButton(
            label: 'Continue',
            loading: _loading,
            onPressed: _loading ? null : _submit,
          ),
          Text.rich(
            TextSpan(
              text: 'By continuing you agree to our ',
              style: TextStyle(
                fontSize: 12,
                color: colors.textTertiary,
                fontWeight: FontWeight.w500,
              ),
              children: [
                WidgetSpan(
                  alignment: PlaceholderAlignment.baseline,
                  baseline: TextBaseline.alphabetic,
                  child: GestureDetector(
                    onTap: () => launchUrl(
                      Uri.parse(SettingsScreen.privacyUrl),
                      mode: LaunchMode.externalApplication,
                    ),
                    child: Text(
                      'Terms and Privacy Policy',
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.brand,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
