import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../utils/color_schema.dart';
import '../../utils/user_provider.dart';
import '../../widgets/neumorpic_button.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailController    = TextEditingController();
  final _passwordController = TextEditingController();
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
      vsync: this,
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
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ── Auth ───────────────────────────────────────────────────────────────────
  Future<void> _login() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      _showSnack('Please fill in all fields.', isError: true);
      return;
    }
    setState(() => _isLoading = true);
    try {
      await Provider.of<UserProvider>(context, listen: false)
          .signIn(_emailController.text.trim(), _passwordController.text);
    } catch (e) {
      if (mounted) _showSnack('Login failed: ${e.toString()}', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
        backgroundColor:
        isError ? AppColors.error : AppColors.primary,
        content: Row(children: [
          Icon(
            isError
                ? Icons.error_outline_rounded
                : Icons.check_circle_outline_rounded,
            color: Colors.white,
            size: 18,
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
            // ── Dark top panel ─────────────────────────────────────────────
            Expanded(flex: 44, child: _buildTopPanel()),

            // ── Light bottom card ──────────────────────────────────────────
            Expanded(
              flex: 56,
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
        // Decorative blobs
        Positioned(
          top: -70, right: -50,
          child: _blob(200, AppColors.primaryLight, 0.12),
        ),
        Positioned(
          bottom: -30, left: -20,
          child: _blob(130, AppColors.primaryGlow, 0.07),
        ),
        Positioned(
          bottom: 30, right: 20,
          child: _blob(80, AppColors.primaryLight, 0.08),
        ),

        // Content
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 18, 28, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildBrandRow(),
                const Spacer(),
                _buildWelcomeText(),
                const SizedBox(height: 22),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _blob(double size, Color color, double opacity) {
    return Container(
      width:  size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(opacity),
      ),
    );
  }

  // ── Brand row ──────────────────────────────────────────────────────────────
  Widget _buildBrandRow() {
    return Row(
      children: [
        // Logo tile
        Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryLight.withOpacity(0.45),
                blurRadius: 16,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Stack(children: [
            const Center(
              child: Text(
                'P',
                style: TextStyle(
                  fontSize:   22,
                  fontWeight: FontWeight.w900,
                  color:      Colors.white,
                  height:     1,
                ),
              ),
            ),
            Positioned(
              top: 7, right: 7,
              child: Container(
                width: 7, height: 7,
                decoration: const BoxDecoration(
                  color: AppColors.primaryGlow,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ]),
        ),
        const SizedBox(width: 12),

        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'PunchIn',
              style: TextStyle(
                fontSize:   18,
                fontWeight: FontWeight.w800,
                color:      Colors.white,
                letterSpacing: 0.2,
              ),
            ),
            Text(
              'ATTENDANCE TRACKER',
              style: TextStyle(
                fontSize:   9.5,
                color:      AppColors.textOnDarkMuted,
                letterSpacing: 1.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Welcome text ───────────────────────────────────────────────────────────
  Widget _buildWelcomeText() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: const [
            Text(
              'Welcome Back',
              style: TextStyle(
                fontSize:   30,
                fontWeight: FontWeight.w800,
                color:      Colors.white,
                letterSpacing: -0.8,
                height:     1.1,
              ),
            ),
            SizedBox(width: 8),
            Text('👋', style: TextStyle(fontSize: 26)),
          ],
        ),

        // Violet accent bar
        Container(
          width: 36, height: 3,
          margin: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(2),
          ),
        ),

        Text(
          "Today is your day. Sign in to start\nmanaging your projects.",
          style: TextStyle(
            fontSize:   13.5,
            color:      AppColors.textOnDarkMuted,
            height:     1.65,
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
        color: AppColors.bgLight,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(26, 30, 26, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _fieldLabel('Email Address'),
            const SizedBox(height: 7),
            _buildEmailField(),
            const SizedBox(height: 16),
            _fieldLabel('Password'),
            const SizedBox(height: 7),
            _buildPasswordField(),
            _buildForgotRow(),
            const SizedBox(height: 20),
            _buildSignInButton(),
            const SizedBox(height: 24),
            _buildDivider(),
            const SizedBox(height: 18),
            _buildSocialRow(),
            const SizedBox(height: 28),
            _buildSignUpRow(),
          ],
        ),
      ),
    );
  }

  // ── Field label ────────────────────────────────────────────────────────────
  Widget _fieldLabel(String text) => Text(
    text,
    style: const TextStyle(
      fontSize:   12.5,
      fontWeight: FontWeight.w600,
      color:      AppColors.textSecondary,
      letterSpacing: 0.2,
    ),
  );

  // ── Email field ────────────────────────────────────────────────────────────
  Widget _buildEmailField() {
    return TextFormField(
      controller:  _emailController,
      keyboardType: TextInputType.emailAddress,
      style: const TextStyle(
        color:      AppColors.textPrimary,
        fontSize:   14,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        hintText:  'example@email.com',
        hintStyle: const TextStyle(
          color:    AppColors.textMuted,
          fontSize: 13.5,
        ),
        prefixIcon: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Icon(
            Icons.mail_outline_rounded,
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
              size: 13,
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
      ),
      onChanged: (v) => setState(() {
        _emailValid = RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v);
      }),
    );
  }

  // ── Password field ─────────────────────────────────────────────────────────
  Widget _buildPasswordField() {
    return TextFormField(
      controller:   _passwordController,
      obscureText:  _obscurePassword,
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
        prefixIcon: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: const Icon(
            Icons.lock_outline_rounded,
            color: AppColors.textMuted,
            size: 18,
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
            size: 18,
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
      ),
    );
  }

  // ── Forgot row ─────────────────────────────────────────────────────────────
  Widget _buildForgotRow() {
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        onPressed: () {},
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: const Text(
          'Forgot Password?',
          style: TextStyle(
            color:      AppColors.primaryLight,
            fontSize:   12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  // ── Sign In button ─────────────────────────────────────────────────────────
  Widget _buildSignInButton() {
    return PunchButton.gold(
      label:     _isLoading ? 'Signing in…' : 'Sign In',
      suffixIcon: _isLoading ? null : Icons.arrow_forward_rounded,
      isLoading: _isLoading,
      size:      PunchButtonSize.full,
      onTap:     _isLoading ? null : _login,
    );
  }

  // ── Divider ────────────────────────────────────────────────────────────────
  Widget _buildDivider() {
    return Row(
      children: [
        const Expanded(child: Divider(color: AppColors.border, thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            'Or continue with',
            style: TextStyle(
              color:      AppColors.textMuted.withOpacity(0.9),
              fontSize:   12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const Expanded(child: Divider(color: AppColors.border, thickness: 1)),
      ],
    );
  }

  // ── Social row ─────────────────────────────────────────────────────────────
  Widget _buildSocialRow() {
    return Row(
      children: [
        Expanded(
          child: _socialBtn(
            icon: SizedBox(
              width: 18, height: 18,
              child: CustomPaint(painter: _GooglePainter()),
            ),
            label: 'Google',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _socialBtn(
            icon: SizedBox(
              width: 18, height: 18,
              child: CustomPaint(painter: _FacebookPainter()),
            ),
            label: 'Facebook',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _socialBtn(
            icon: Icon(
              Icons.apple_rounded,
              size:  20,
              color: AppColors.textPrimary,
            ),
            label: 'Apple',
          ),
        ),
      ],
    );
  }

  Widget _socialBtn({required Widget icon, required String label}) {
    return OutlinedButton(
      onPressed: () {},
      style: OutlinedButton.styleFrom(
        padding:         const EdgeInsets.symmetric(vertical: 12),
        side:            const BorderSide(color: AppColors.border, width: 1.2),
        backgroundColor: AppColors.bgWhite,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          const SizedBox(height: 5),
          Text(
            label,
            style: const TextStyle(
              color:      AppColors.textSecondary,
              fontSize:   11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  // ── Sign up row ────────────────────────────────────────────────────────────
  Widget _buildSignUpRow() {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            "Don't have an account? ",
            style: TextStyle(
              color:    AppColors.textMuted,
              fontSize: 13,
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SignupScreen()),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 11, vertical: 4),
              decoration: BoxDecoration(
                color:        AppColors.primaryTint,
                borderRadius: BorderRadius.circular(7),
              ),
              child: const Text(
                'Sign up',
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
}

// ── Google logo painter ───────────────────────────────────────────────────────
class _GooglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const pi = 3.14159265358979;
    final c  = Offset(size.width / 2, size.height / 2);
    final sw = size.width;
    final strokeW = sw * 0.20;
    final r = sw / 2 - strokeW / 2;

    void arc(double startDeg, double sweepDeg, Color color) {
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        startDeg * pi / 180,
        sweepDeg * pi / 180,
        false,
        Paint()
          ..color      = color
          ..strokeWidth = strokeW
          ..style       = PaintingStyle.stroke
          ..strokeCap   = StrokeCap.butt,
      );
    }

    arc(30,  120, const Color(0xFF4285F4));
    arc(150,  65, const Color(0xFF34A853));
    arc(215,  65, const Color(0xFFFBBC05));
    arc(280,  50, const Color(0xFFEA4335));

    final arm = Paint()
      ..color      = const Color(0xFF4285F4)
      ..strokeWidth = strokeW
      ..strokeCap   = StrokeCap.square;
    canvas.drawLine(c, Offset(c.dx + r + strokeW / 2, c.dy), arm);
    canvas.drawLine(
      Offset(c.dx + r, c.dy),
      Offset(c.dx + r, c.dy + r * 0.48),
      arm,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ── Facebook logo painter ─────────────────────────────────────────────────────
class _FacebookPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final sw = size.width;
    final sh = size.height;

    canvas.drawCircle(
      Offset(sw / 2, sh / 2),
      sw / 2,
      Paint()..color = const Color(0xFF1877F2),
    );

    final tp = TextPainter(
      text: TextSpan(
        text: 'f',
        style: TextStyle(
          color:      Colors.white,
          fontSize:   sw * 0.72,
          fontWeight: FontWeight.w900,
          height:     1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    tp.paint(
      canvas,
      Offset(sw * 0.5 - tp.width * 0.38, sh * 0.5 - tp.height * 0.48),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}