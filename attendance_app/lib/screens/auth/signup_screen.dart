import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../utils/user_provider.dart';

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
  final _companyController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  void _signup() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await Provider.of<UserProvider>(context, listen: false).signUpAdmin(
        _nameController.text.trim(),
        _emailController.text.trim(),
        _passwordController.text,
        _companyController.text.trim(),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text('Registration failed: ${e.toString()}')),
            ]),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('Register Company'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.business_center_rounded, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('New Company', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Text('Create your admin account', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionLabel('Company Information'),
                    const SizedBox(height: 12),
                    _buildField(_companyController, 'Company Name', Icons.business_rounded,
                        hint: 'e.g. Acme Corp'),
                    const SizedBox(height: 28),
                    _buildSectionLabel('Administrator Details'),
                    const SizedBox(height: 12),
                    _buildField(_nameController, 'Your Full Name', Icons.person_rounded,
                        hint: 'e.g. John Doe'),
                    const SizedBox(height: 16),
                    _buildField(_emailController, 'Work Email', Icons.alternate_email_rounded,
                        hint: 'you@company.com', keyboard: TextInputType.emailAddress),
                    const SizedBox(height: 16),
                    _buildPasswordField(),
                    const SizedBox(height: 36),
                    _isLoading
                        ? const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)))
                        : ElevatedButton(
                            onPressed: _signup,
                            child: const Text('CREATE COMPANY ACCOUNT'),
                          ),
                    const SizedBox(height: 16),
                    Center(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Already have an account? Sign In',
                            style: TextStyle(color: Color(0xFF6366F1))),
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

  Widget _buildSectionLabel(String label) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8), letterSpacing: 1.2),
    );
  }

  Widget _buildField(TextEditingController controller, String label, IconData icon,
      {String? hint, bool obscure = false, TextInputType? keyboard}) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboard,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF475569)),
        prefixIcon: Icon(icon, size: 20),
      ),
      validator: (v) => v == null || v.isEmpty ? 'This field is required' : null,
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: 'Password',
        hintText: 'At least 8 characters',
        hintStyle: const TextStyle(color: Color(0xFF475569)),
        prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 20,
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
