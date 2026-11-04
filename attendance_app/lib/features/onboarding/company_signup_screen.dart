import 'package:flutter/material.dart';

import 'package:attendance_app/core/di/injection.dart';
import 'package:attendance_app/core/error/app_exception.dart';
import 'package:attendance_app/core/theme/app_colors.dart';
import 'package:attendance_app/core/theme/app_spacing.dart';
import 'package:attendance_app/core/widgets/app_button.dart';
import 'package:attendance_app/domain/repositories/auth_repository.dart';

/// Step 1 of company signup: the admin's own account. Once it exists the app
/// routes to [CompanySetupScreen] (also after a restart mid-way).
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
      // The auth state change takes over and shows company setup.
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
    final text = Theme.of(context).textTheme;
    String? required(String? v) =>
        v == null || v.trim().isEmpty ? 'Required' : null;

    return Scaffold(
      appBar: AppBar(title: const Text('Step 1 of 2')),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            children: [
              Text(
                'Create your admin account',
                style: text.displaySmall?.copyWith(fontSize: 26),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'You’ll use this to manage your company. Employees sign in '
                'with their phone instead.',
                style: text.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.xxl),
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Your name'),
                validator: required,
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                decoration: const InputDecoration(labelText: 'Work email'),
                validator: (v) => v == null || !v.contains('@')
                    ? 'Enter a valid email'
                    : null,
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _password,
                obscureText: _obscure,
                onFieldSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: 'Password',
                  helperText: 'At least 8 characters',
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
                validator: (v) => v == null || v.length < 8
                    ? 'Use at least 8 characters'
                    : null,
              ),
              const SizedBox(height: AppSpacing.xxl),
              AppButton(
                label: 'Continue',
                loading: _loading,
                onPressed: _loading ? null : _submit,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'By continuing you agree to the PunchIn terms and privacy '
                'policy.',
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
