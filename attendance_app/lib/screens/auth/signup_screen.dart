import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../utils/color_schema.dart';
import '../../utils/user_provider.dart';
import '../../widgets/neumorpic_button.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen>
    with SingleTickerProviderStateMixin {
  final _formKey           = GlobalKey<FormState>();
  final _nameController    = TextEditingController();
  final _emailController   = TextEditingController();
  final _passwordController= TextEditingController();
  final _companyController = TextEditingController();

  bool _isLoading       = false;
  bool _obscurePassword = true;
  bool _emailValid      = false;

  late AnimationController _animController;
  late Animation<Offset>   _slideAnim;
  late Animation<double>   _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 680),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.16),
      end:   Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve:  Curves.easeOutCubic,
    ));
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve:  Curves.easeIn,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _companyController.dispose();
    super.dispose();
  }

  // ── Auth ───────────────────────────────────────────────────────────────────
  Future<void> _signup() async {
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
      if (mounted) _showSnack('Registration failed: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior:        SnackBarBehavior.floating,
        margin:          const EdgeInsets.fromLTRB(16, 0, 16, 16),
        backgroundColor: AppColors.error,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 0,
        content: Row(children: [
          const Icon(
            Icons.error_outline_rounded,
            color: Colors.white,
            size:  18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              msg,
              style: const TextStyle(
                color:      Colors.white,
                fontSize:   13.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ]),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.bgDark,
        body: Column(
          children: [
            // Dark top panel
            Expanded(flex: 38, child: _buildTopPanel()),

            // Light form card
            Expanded(
              flex: 62,
              child: SlideTransition(
                position: _slideAnim,
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: _buildFormCard(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Top panel ──────────────────────────────────────────────────────────────
  Widget _buildTopPanel() {
    return Stack(
      children: [
        // Blobs
        Positioned(
          top: -60, right: -40,
          child: _blob(180, AppColors.primaryLight, 0.12),
        ),
        Positioned(
          bottom: -20, left: -10,
          child: _blob(110, AppColors.primaryGlow, 0.07),
        ),

        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTopBar(),
                const Spacer(),
                _buildHeading(),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _blob(double size, Color color, double opacity) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: color.withOpacity(opacity),
    ),
  );

  // ── Top bar — back + brand + step badge ────────────────────────────────────
  Widget _buildTopBar() {
    return Row(
      children: [
        // Back button
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color:        AppColors.bgSurface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.borderDark, width: 1),
            ),
            child: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
              size:  15,
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Brand
        Container(
          width: 30, height: 30,
          decoration: BoxDecoration(
            color:        AppColors.primaryLight,
            borderRadius: BorderRadius.circular(9),
            boxShadow: [
              BoxShadow(
                color:      AppColors.primaryLight.withOpacity(0.40),
                blurRadius: 10,
                offset:     const Offset(0, 3),
              ),
            ],
          ),
          child: Stack(children: [
            const Center(
              child: Text(
                'P',
                style: TextStyle(
                  fontSize:   16,
                  fontWeight: FontWeight.w900,
                  color:      Colors.white,
                  height:     1,
                ),
              ),
            ),
            Positioned(
              top: 5, right: 5,
              child: Container(
                width: 5, height: 5,
                decoration: const BoxDecoration(
                  color: AppColors.primaryGlow,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ]),
        ),
        const SizedBox(width: 8),
        const Text(
          'PunchIn',
          style: TextStyle(
            fontSize:   15,
            fontWeight: FontWeight.w800,
            color:      Colors.white,
          ),
        ),

        const Spacer(),

        // Step badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color:        AppColors.bgSurface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.borderDark, width: 1),
          ),
          child: const Text(
            'Step 1 of 2',
            style: TextStyle(
              fontSize:   10,
              fontWeight: FontWeight.w700,
              color:      AppColors.primaryGlow,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ],
    );
  }

  // ── Heading ────────────────────────────────────────────────────────────────
  Widget _buildHeading() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            Text(
              'Create Account',
              style: TextStyle(
                fontSize:   24,
                fontWeight: FontWeight.w800,
                color:      Colors.white,
                letterSpacing: -0.6,
                height:     1.15,
              ),
            ),
            SizedBox(width: 8),
            Text('🏢', style: TextStyle(fontSize: 22)),
          ],
        ),
        Container(
          width: 28, height: 3,
          margin: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color:        AppColors.primaryLight,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Text(
          'Set up your company and admin\nprofile to get started.',
          style: TextStyle(
            fontSize:   12.5,
            color:      AppColors.textOnDarkMuted,
            height:     1.6,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  // ── Form card ──────────────────────────────────────────────────────────────
  Widget _buildFormCard() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color:        AppColors.bgLight,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 26, 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Progress bar
              _buildProgressBar(),
              const SizedBox(height: 22),

              // ── Company section ──────────────────────────────────────────
              _buildSectionHeader(
                icon:  Icons.business_rounded,
                label: 'Company Information',
              ),
              const SizedBox(height: 12),
              _buildField(
                controller: _companyController,
                label:      'Company Name',
                hint:       'e.g. Acme Corp',
                icon:       Icons.domain_rounded,
                validator:  _requiredValidator,
              ),
              const SizedBox(height: 22),

              // ── Admin section ────────────────────────────────────────────
              _buildSectionHeader(
                icon:  Icons.person_rounded,
                label: 'Administrator Details',
              ),
              const SizedBox(height: 12),
              _buildField(
                controller: _nameController,
                label:      'Full Name',
                hint:       'e.g. John Doe',
                icon:       Icons.person_outline_rounded,
                validator:  _requiredValidator,
              ),
              const SizedBox(height: 14),
              _buildEmailField(),
              const SizedBox(height: 14),
              _buildPasswordField(),
              const SizedBox(height: 28),

              // ── Submit ───────────────────────────────────────────────────
              _buildSubmitButton(),
              const SizedBox(height: 18),
              _buildSignInRow(),
            ],
          ),
        ),
      ),
    );
  }

  // ── Progress bar ──────────────────────────────────────────────────────────
  Widget _buildProgressBar() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 3,
            decoration: BoxDecoration(
              color:        AppColors.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Container(
            height: 3,
            decoration: BoxDecoration(
              color:        AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ],
    );
  }

  // ── Section header ────────────────────────────────────────────────────────
  Widget _buildSectionHeader({
    required IconData icon,
    required String   label,
  }) {
    return Row(
      children: [
        Container(
          width: 28, height: 28,
          decoration: BoxDecoration(
            color:        AppColors.primaryTint,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppColors.primary, size: 14),
        ),
        const SizedBox(width: 9),
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize:   10.5,
            fontWeight: FontWeight.w700,
            color:      AppColors.textSecondary,
            letterSpacing: 0.9,
          ),
        ),
      ],
    );
  }

  // ── Generic text field ────────────────────────────────────────────────────
  Widget _buildField({
    required TextEditingController controller,
    required String                label,
    required String                hint,
    required IconData              icon,
    required String? Function(String?) validator,
    TextInputType?                 keyboard,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(label),
        const SizedBox(height: 6),
        TextFormField(
          controller:  controller,
          keyboardType: keyboard,
          style: const TextStyle(
            color:      AppColors.textPrimary,
            fontSize:   14,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText:  hint,
            hintStyle: const TextStyle(
              color:    AppColors.textMuted,
              fontSize: 13.5,
            ),
            prefixIcon: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Icon(icon, color: AppColors.textMuted, size: 18),
            ),
            prefixIconConstraints:
            const BoxConstraints(minWidth: 46, minHeight: 46),
            filled:    true,
            fillColor: AppColors.bgWhite,
            contentPadding:
            const EdgeInsets.symmetric(vertical: 15, horizontal: 16),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                  color: AppColors.border, width: 1.2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                  color: AppColors.borderStrong, width: 1.6),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                  color: AppColors.error, width: 1.2),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                  color: AppColors.error, width: 1.6),
            ),
            errorStyle: const TextStyle(
              color:      AppColors.error,
              fontSize:   11.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          validator: validator,
        ),
      ],
    );
  }

  // ── Email field ────────────────────────────────────────────────────────────
  Widget _buildEmailField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel('Work Email'),
        const SizedBox(height: 6),
        TextFormField(
          controller:   _emailController,
          keyboardType: TextInputType.emailAddress,
          style: const TextStyle(
            color:      AppColors.textPrimary,
            fontSize:   14,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText:  'you@company.com',
            hintStyle: const TextStyle(
              color:    AppColors.textMuted,
              fontSize: 13.5,
            ),
            prefixIcon: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Icon(
                Icons.alternate_email_rounded,
                color: _emailValid
                    ? AppColors.primary
                    : AppColors.textMuted,
                size: 18,
              ),
            ),
            prefixIconConstraints:
            const BoxConstraints(minWidth: 46, minHeight: 46),
            suffixIcon: _emailValid
                ? Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Container(
                width: 20, height: 20,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
                  color: Colors.white,
                  size:  13,
                ),
              ),
            )
                : null,
            suffixIconConstraints:
            const BoxConstraints(minWidth: 44, minHeight: 44),
            filled:    true,
            fillColor: AppColors.bgWhite,
            contentPadding:
            const EdgeInsets.symmetric(vertical: 15, horizontal: 16),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                  color: AppColors.border, width: 1.2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                  color: AppColors.borderStrong, width: 1.6),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                  color: AppColors.error, width: 1.2),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                  color: AppColors.error, width: 1.6),
            ),
            errorStyle: const TextStyle(
              color:      AppColors.error,
              fontSize:   11.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          onChanged: (v) => setState(() {
            _emailValid =
                RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v);
          }),
          validator: (v) {
            if (v == null || v.isEmpty) return 'Email is required';
            if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v)) {
              return 'Enter a valid email address';
            }
            return null;
          },
        ),
      ],
    );
  }

  // ── Password field ────────────────────────────────────────────────────────
  Widget _buildPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel('Password'),
        const SizedBox(height: 6),
        TextFormField(
          controller:  _passwordController,
          obscureText: _obscurePassword,
          style: const TextStyle(
            color:      AppColors.textPrimary,
            fontSize:   14,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText:  'At least 8 characters',
            hintStyle: const TextStyle(
              color:    AppColors.textMuted,
              fontSize: 13.5,
            ),
            prefixIcon: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14),
              child: Icon(
                Icons.lock_outline_rounded,
                color: AppColors.textMuted,
                size:  18,
              ),
            ),
            prefixIconConstraints:
            const BoxConstraints(minWidth: 46, minHeight: 46),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: AppColors.textMuted,
                size:  18,
              ),
              splashRadius: 20,
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
            filled:    true,
            fillColor: AppColors.bgWhite,
            contentPadding:
            const EdgeInsets.symmetric(vertical: 15, horizontal: 16),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                  color: AppColors.border, width: 1.2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                  color: AppColors.borderStrong, width: 1.6),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                  color: AppColors.error, width: 1.2),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                  color: AppColors.error, width: 1.6),
            ),
            errorStyle: const TextStyle(
              color:      AppColors.error,
              fontSize:   11.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          validator: (v) {
            if (v == null || v.isEmpty) return 'Password is required';
            if (v.length < 8) return 'Must be at least 8 characters';
            return null;
          },
        ),

        // Password strength hint
        const SizedBox(height: 8),
        _buildPasswordStrengthRow(),
      ],
    );
  }

  // ── Password strength ─────────────────────────────────────────────────────
  Widget _buildPasswordStrengthRow() {
    final len = _passwordController.text.length;
    final Color barColor;
    final String label;

    if (len == 0) {
      return const SizedBox.shrink();
    } else if (len < 6) {
      barColor = AppColors.error;
      label    = 'Weak';
    } else if (len < 10) {
      barColor = AppColors.warning;
      label    = 'Fair';
    } else {
      barColor = AppColors.success;
      label    = 'Strong';
    }

    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value:           (len.clamp(0, 12) / 12).toDouble(),
              minHeight:       3,
              backgroundColor: AppColors.border,
              valueColor:      AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            fontSize:   11,
            fontWeight: FontWeight.w600,
            color:      barColor,
          ),
        ),
      ],
    );
  }

  // ── Submit button ─────────────────────────────────────────────────────────
  Widget _buildSubmitButton() {
    return PunchButton.gold(
      label:     _isLoading ? 'Creating account…' : 'Create Company Account',
      suffixIcon: _isLoading ? null : Icons.arrow_forward_rounded,
      isLoading: _isLoading,
      size:      PunchButtonSize.full,
      onTap:     _isLoading ? null : _signup,
    );
  }

  // ── Sign in row ───────────────────────────────────────────────────────────
  Widget _buildSignInRow() {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Already have an account? ',
            style: TextStyle(
              color:    AppColors.textMuted,
              fontSize: 13,
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 11, vertical: 4),
              decoration: BoxDecoration(
                color:        AppColors.primaryTint,
                borderRadius: BorderRadius.circular(7),
              ),
              child: const Text(
                'Sign In',
                style: TextStyle(
                  color:      AppColors.primary,
                  fontSize:   13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  Widget _fieldLabel(String text) => Text(
    text,
    style: const TextStyle(
      fontSize:   12.5,
      fontWeight: FontWeight.w600,
      color:      AppColors.textSecondary,
      letterSpacing: 0.2,
    ),
  );

  String? _requiredValidator(String? v) =>
      (v == null || v.trim().isEmpty) ? 'This field is required' : null;
}