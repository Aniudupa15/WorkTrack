import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:attendance_app/core/error/app_exception.dart';
import 'package:attendance_app/core/theme/app_colors.dart';
import 'package:attendance_app/core/theme/app_spacing.dart';
import 'package:attendance_app/features/shared/user_provider.dart';

enum _SignupMode { registerCompany, joinCompany }

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  // Company name (register) or company code (join), depending on the mode.
  final _companyController = TextEditingController();
  _SignupMode _mode = _SignupMode.registerCompany;
  bool _isLoading = false;
  bool _obscurePassword = true;

  bool get _isRegister => _mode == _SignupMode.registerCompany;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _companyController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final provider = Provider.of<UserProvider>(context, listen: false);
      if (_isRegister) {
        await provider.signUpAdmin(
          _nameController.text.trim(),
          _emailController.text.trim(),
          _passwordController.text,
          _companyController.text.trim(),
        );
      } else {
        await provider.signUpEmployee(
          _nameController.text.trim(),
          _emailController.text.trim(),
          _passwordController.text,
          _companyController.text.trim(),
        );
      }
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
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Account'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SegmentedButton<_SignupMode>(
                segments: const [
                  ButtonSegment(
                    value: _SignupMode.registerCompany,
                    label: Text('Register Company'),
                    icon: Icon(Icons.business_center_rounded, size: 18),
                  ),
                  ButtonSegment(
                    value: _SignupMode.joinCompany,
                    label: Text('Join Company'),
                    icon: Icon(Icons.groups_rounded, size: 18),
                  ),
                ],
                selected: {_mode},
                onSelectionChanged: (s) => setState(() => _mode = s.first),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                _isRegister ? 'New Company' : 'Join Your Team',
                style: text.titleLarge,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                _isRegister
                    ? "Create your company and admin account. You'll get a company code to invite employees."
                    : 'Enter the company code your admin shared with you.',
                style: text.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.xxl),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    _field(
                      _companyController,
                      _isRegister ? 'Company Name' : 'Company Code',
                      _isRegister ? Icons.business_rounded : Icons.key_rounded,
                      hint: _isRegister ? 'e.g. Acme Corp' : 'Paste the code',
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _field(
                      _nameController,
                      'Your Full Name',
                      Icons.person_rounded,
                      hint: 'e.g. John Doe',
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _field(
                      _emailController,
                      'Work Email',
                      Icons.alternate_email_rounded,
                      hint: 'you@company.com',
                      keyboard: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _passwordField(),
                    const SizedBox(height: AppSpacing.xxxl),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _submit,
                      child: _isLoading
                          ? SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: colors.onBrand,
                              ),
                            )
                          : Text(
                              _isRegister
                                  ? 'CREATE COMPANY ACCOUNT'
                                  : 'JOIN COMPANY',
                            ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Center(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Already have an account? Sign In'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboard,
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
