import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:attendance_app/core/error/app_exception.dart';
import 'package:attendance_app/core/theme/app_colors.dart';
import 'package:attendance_app/core/theme/app_spacing.dart';
import 'package:attendance_app/core/widgets/app_button.dart';
import 'package:attendance_app/features/shared/user_provider.dart';

/// A single registration screen. There is no admin/employee choice — the code
/// the user enters (minted by a super admin or their company admin) determines
/// their role automatically.
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await Provider.of<UserProvider>(context, listen: false).signUpWithCode(
        _nameController.text.trim(),
        _emailController.text.trim(),
        _passwordController.text,
        _codeController.text.trim(),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        final message = e is AppException ? e.message : 'Registration failed.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: context.colors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Account'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'JOIN WITH A COMPANY CODE',
                  style: text.bodySmall?.copyWith(
                    letterSpacing: 1.6,
                    fontWeight: FontWeight.w700,
                    color: context.colors.textTertiary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Join your\nteam.',
                  style: text.displaySmall?.copyWith(fontSize: 34),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Enter the code your admin shared with you. PunchIn assigns '
                  'your role automatically — there’s no admin/employee choice to '
                  'make here.',
                  style: text.bodyMedium?.copyWith(height: 1.5),
                ),
                const SizedBox(height: AppSpacing.xxl),
                _field(
                  _codeController,
                  'Company code',
                  Icons.key_rounded,
                  hint: 'e.g. 4F7K2Q',
                  caps: true,
                ),
                const SizedBox(height: AppSpacing.md),
                _field(
                  _nameController,
                  'Your full name',
                  Icons.person_outline_rounded,
                  hint: 'e.g. Priya Sharma',
                ),
                const SizedBox(height: AppSpacing.md),
                _field(
                  _emailController,
                  'Work email',
                  Icons.alternate_email_rounded,
                  hint: 'you@company.com',
                  keyboard: TextInputType.emailAddress,
                ),
                const SizedBox(height: AppSpacing.md),
                _passwordField(),
                const SizedBox(height: AppSpacing.xxxl),
                AppButton(
                  label: 'Join company',
                  icon: Icons.arrow_forward_rounded,
                  loading: _isLoading,
                  onPressed: _isLoading ? null : _submit,
                ),
                const SizedBox(height: AppSpacing.md),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Already have an account? Sign In'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon, {
    String? hint,
    TextInputType? keyboard,
    bool caps = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboard,
      textCapitalization: caps
          ? TextCapitalization.characters
          : TextCapitalization.none,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 20),
      ),
      validator: (v) =>
          v == null || v.trim().isEmpty ? 'This field is required' : null,
    );
  }

  Widget _passwordField() {
    return TextFormField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      decoration: InputDecoration(
        labelText: 'Password',
        hintText: 'At least 8 characters',
        prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword
                ? Icons.visibility_off_rounded
                : Icons.visibility_rounded,
            size: 20,
          ),
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
        ),
      ),
      validator: (v) {
        if (v == null || v.isEmpty) return 'Password is required';
        if (v.length < 8) return 'Password must be at least 8 characters';
        return null;
      },
    );
  }
}
