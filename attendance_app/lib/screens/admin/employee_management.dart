import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../utils/color_schema.dart';
import '../../utils/user_provider.dart';
import '../../services/auth_service.dart';
import '../../services/location_service.dart';
import '../../widgets/neumorpic_button.dart';

class EmployeeManagement extends StatelessWidget {
  const EmployeeManagement({super.key});

  @override
  State<EmployeeManagement> createState() =>
      _EmployeeManagementState();
}

class _EmployeeManagementState extends State<EmployeeManagement>
    with SingleTickerProviderStateMixin {
  final _formKey           = GlobalKey<FormState>();
  final _nameController    = TextEditingController();
  final _emailController   = TextEditingController();
  final _passwordController= TextEditingController();
  final _latController     = TextEditingController();
  final _lngController     = TextEditingController();
  final _radiusController  = TextEditingController(text: '100');
  final _startController   = TextEditingController(text: '09:00');
  final _endController     = TextEditingController(text: '18:00');

  bool _isLoading       = false;
  bool _obscurePassword = true;
  bool _emailValid      = false;
  bool _fetchingLoc     = false;

  final _auth            = AuthService();
  final _locationService = LocationService();

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
      begin: const Offset(0, 0.14),
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
    _latController.dispose();
    _lngController.dispose();
    _radiusController.dispose();
    _startController.dispose();
    _endController.dispose();
    super.dispose();
  }

  // ── Add employee ───────────────────────────────────────────────────────────
  Future<void> _addEmployee() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final employee = UserModel(
        id:    '',
        name:  _nameController.text.trim(),
        email: _emailController.text.trim(),
        role:  'employee',
        assignedLocation: {
          'lat': double.parse(_latController.text),
          'lng': double.parse(_lngController.text),
        },
        radius:     double.parse(_radiusController.text),
        shiftStart: _startController.text,
        shiftEnd:   _endController.text,
      );

      final result = await _auth.registerEmployee(
        employee,
        _passwordController.text,
        Provider.of<UserProvider>(context, listen: false)
            .user
            ?.companyId ??
            '',
      );
      if (result != null && mounted) {
        _showSuccessDialog(employee, _passwordController.text);
      }
    } catch (e) {
      if (mounted) _showSnack('Error: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Fetch GPS ──────────────────────────────────────────────────────────────
  Future<void> _getCurrentLocation() async {
    setState(() => _fetchingLoc = true);
    try {
      final pos = await _locationService.getCurrentLocation();
      if (pos != null && mounted) {
        setState(() {
          _latController.text = pos.latitude.toStringAsFixed(6);
          _lngController.text = pos.longitude.toStringAsFixed(6);
        });
      }
    } catch (e) {
      if (mounted) _showSnack('Could not get location: $e');
    } finally {
      if (mounted) setState(() => _fetchingLoc = false);
    }
  }

  // ── Snack ──────────────────────────────────────────────────────────────────
  void _showSnack(String msg, {bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior:        SnackBarBehavior.floating,
        margin:          const EdgeInsets.fromLTRB(16, 0, 16, 16),
        backgroundColor: isSuccess ? AppColors.success : AppColors.error,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 0,
        content: Row(children: [
          Icon(
            isSuccess
                ? Icons.check_circle_outline_rounded
                : Icons.error_outline_rounded,
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

  // ── Success dialog ─────────────────────────────────────────────────────────
  void _showSuccessDialog(UserModel employee, String password) {
    final companyName =
        Provider.of<UserProvider>(context, listen: false)
            .company
            ?.name ??
            'your company';

    showDialog(
      context:           context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding:    const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          decoration: BoxDecoration(
            color:        AppColors.bgWhite,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color:      AppColors.primary.withOpacity(0.15),
                blurRadius: 40,
                offset:     const Offset(0, 12),
              ),
            ],
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Success icon
              Container(
                width: 64, height: 64,
                decoration: const BoxDecoration(
                  color:  AppColors.successSurface,
                  shape:  BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.success,
                  size:  34,
                ),
              ),
              const SizedBox(height: 16),

              const Text(
                'Employee Created!',
                style: TextStyle(
                  fontSize:   18,
                  fontWeight: FontWeight.w800,
                  color:      AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${employee.name}\'s account has been set up.\nShare the credentials below.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color:    AppColors.textMuted,
                  height:   1.55,
                ),
              ),
              const SizedBox(height: 20),

              // Credentials box
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color:        AppColors.bgLight,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: AppColors.border, width: 1),
                ),
                child: Column(
                  children: [
                    _credRow('Full Name',  employee.name),
                    _dividerLine(),
                    _credRow('Email',      employee.email),
                    _dividerLine(),
                    _credRow('Password',   password),
                    _dividerLine(),
                    _credRow('Shift',
                        '${employee.shiftStart} – ${employee.shiftEnd}'),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Actions
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.pop(context);
                      },
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 46),
                        side: const BorderSide(
                            color: AppColors.border, width: 1.2),
                        backgroundColor: AppColors.bgLight,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Done',
                        style: TextStyle(
                          color:      AppColors.textSecondary,
                          fontWeight: FontWeight.w700,
                          fontSize:   13.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        final msg =
                            '👋 Welcome to $companyName!\n\n'
                            'Your attendance account is ready:\n'
                            '📧 Email: ${employee.email}\n'
                            '🔑 Password: $password\n\n'
                            'Download PunchIn to start checking in.';
                        Share.share(msg);
                      },
                      icon: const Icon(Icons.share_rounded, size: 16),
                      label: const Text('Share'),
                      style: ElevatedButton.styleFrom(
                        minimumSize:      const Size(0, 46),
                        backgroundColor:  AppColors.primary,
                        foregroundColor:  Colors.white,
                        elevation:        0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        textStyle: const TextStyle(
                          fontSize:   13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _credRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize:   12,
              color:      AppColors.textMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize:   12.5,
              fontWeight: FontWeight.w700,
              color:      AppColors.textPrimary,
            ),
          ),
        ),
        backgroundColor: const Color(0xFF6366F1),
        child: const Icon(Icons.person_add, color: Colors.white),
      ),
    );
  }
}

  Widget _dividerLine() => const Divider(
    height: 1,
    color:  AppColors.border,
    thickness: 1,
  );

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.bgDark,
        body: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SlideTransition(
                position: _slideAnim,
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: _buildFormBody(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Dark header ────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return SafeArea(
      bottom: false,
      child: Stack(
        children: [
          Positioned(
            top: -60, right: -40,
            child: _blob(150, AppColors.primaryLight, 0.10),
          ),
          Positioned(
            bottom: -20, left: -20,
            child: _blob(90, AppColors.primaryGlow, 0.06),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top bar
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color:        AppColors.bgSurface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: AppColors.borderDark, width: 1),
                        ),
                        child: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white,
                          size:  15,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Add Employee',
                      style: TextStyle(
                        fontSize:   17,
                        fontWeight: FontWeight.w800,
                        color:      Colors.white,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color:        AppColors.bgSurface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: AppColors.borderDark, width: 1),
                      ),
                      child: const Text(
                        '3 sections',
                        style: TextStyle(
                          fontSize:   10,
                          fontWeight: FontWeight.w700,
                          color:      AppColors.primaryGlow,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Fill in the details below to create a new\nemployee account and assign their location.',
                  style: TextStyle(
                    fontSize:   12.5,
                    color:      AppColors.textOnDarkMuted,
                    height:     1.55,
                  ),
                ),
                const SizedBox(height: 14),
                // Progress bar (3 segments, all filled)
                Row(
                  children: List.generate(3, (i) => Expanded(
                    child: Container(
                      height: 3,
                      margin: EdgeInsets.only(right: i < 2 ? 6 : 0),
                      decoration: BoxDecoration(
                        color: i < 2
                            ? AppColors.primaryLight
                            : AppColors.borderDark,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  )),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _blob(double size, Color color, double opacity) =>
      Container(
        width: size, height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withOpacity(opacity),
        ),
      );

  // ── Form body ──────────────────────────────────────────────────────────────
  Widget _buildFormBody() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color:        AppColors.bgLight,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Personal Details ───────────────────────────────────────
              _sectionHeader(Icons.person_rounded, 'Personal Details'),
              const SizedBox(height: 14),
              _buildField(
                controller: _nameController,
                label:      'Full Name',
                hint:       'e.g. Rahul Mehta',
                icon:       Icons.person_outline_rounded,
                validator:  _required,
              ),
              const SizedBox(height: 13),
              _buildEmailField(),
              const SizedBox(height: 13),
              _buildPasswordField(),

              _sectionDivider(),

              // ── Work Location ──────────────────────────────────────────
              _sectionHeader(Icons.location_on_rounded, 'Work Location'),
              const SizedBox(height: 14),
              _buildCoordinatesRow(),
              const SizedBox(height: 13),
              _buildField(
                controller:  _radiusController,
                label:       'Allowed Radius (meters)',
                hint:        'e.g. 100',
                icon:        Icons.radar_rounded,
                keyboard:    TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
                validator: _required,
              ),

              _sectionDivider(),

              // ── Shift Schedule ─────────────────────────────────────────
              _sectionHeader(Icons.schedule_rounded, 'Shift Schedule'),
              const SizedBox(height: 14),
              _buildShiftRow(),

              const SizedBox(height: 32),

              // ── Submit ─────────────────────────────────────────────────
              PunchButton.gold(
                label:     _isLoading
                    ? 'Creating account…'
                    : 'Create Employee Account',
                suffixIcon: _isLoading
                    ? null
                    : Icons.arrow_forward_rounded,
                isLoading: _isLoading,
                size:      PunchButtonSize.full,
                onTap:     _isLoading ? null : _addEmployee,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Section header ─────────────────────────────────────────────────────────
  Widget _sectionHeader(IconData icon, String label) {
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

  Widget _sectionDivider() => const Padding(
    padding: EdgeInsets.symmetric(vertical: 20),
    child: Divider(color: AppColors.border, height: 1),
  );

  // ── Generic field ──────────────────────────────────────────────────────────
  Widget _buildField({
    required TextEditingController        controller,
    required String                       label,
    required String                       hint,
    required IconData                     icon,
    required String? Function(String?)    validator,
    bool                                  obscure = false,
    TextInputType?                        keyboard,
    List<TextInputFormatter>?             inputFormatters,
    Widget?                               suffix,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(label),
        const SizedBox(height: 6),
        TextFormField(
          controller:       controller,
          obscureText:      obscure,
          keyboardType:     keyboard,
          inputFormatters:  inputFormatters,
          style: const TextStyle(
            color:      AppColors.textPrimary,
            fontSize:   14,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText:  hint,
            hintStyle: const TextStyle(
                color: AppColors.textMuted, fontSize: 13.5),
            prefixIcon: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Icon(icon, color: AppColors.textMuted, size: 18),
            ),
            prefixIconConstraints:
            const BoxConstraints(minWidth: 46, minHeight: 46),
            suffixIcon: suffix,
            filled:    true,
            fillColor: AppColors.bgWhite,
            contentPadding: const EdgeInsets.symmetric(
                vertical: 15, horizontal: 16),
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
    return _buildField(
      controller: _emailController,
      label:      'Email Address',
      hint:       'rahul@company.com',
      icon:       Icons.alternate_email_rounded,
      keyboard:   TextInputType.emailAddress,
      suffix: _emailValid
          ? Padding(
        padding: const EdgeInsets.only(right: 12),
        child: Container(
          width: 20, height: 20,
          decoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check,
              color: Colors.white, size: 13),
        ),
      )
          : null,
      validator: (v) {
        if (v == null || v.isEmpty) return 'Email is required';
        if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v)) {
          return 'Enter a valid email';
        }
        return null;
      },
    );
    // Wire onChanged separately via a wrapper
  }

  // ── Password field ─────────────────────────────────────────────────────────
  Widget _buildPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel('Temporary Password'),
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
                color: AppColors.textMuted, fontSize: 13.5),
            prefixIcon: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14),
              child: Icon(Icons.lock_outline_rounded,
                  color: AppColors.textMuted, size: 18),
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
              onPressed: () => setState(
                      () => _obscurePassword = !_obscurePassword),
            ),
            filled:    true,
            fillColor: AppColors.bgWhite,
            contentPadding: const EdgeInsets.symmetric(
                vertical: 15, horizontal: 16),
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
            if (v.length < 6) return 'Minimum 6 characters';
            return null;
          },
        ),
      ],
    );
  }

  // ── Coordinates row ────────────────────────────────────────────────────────
  Widget _buildCoordinatesRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel('GPS Coordinates'),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _miniField(
                controller: _latController,
                hint:       'Latitude',
                icon:       Icons.south_rounded,
                validator:  _required,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _miniField(
                controller: _lngController,
                hint:       'Longitude',
                icon:       Icons.east_rounded,
                validator:  _required,
              ),
            ),
            const SizedBox(width: 8),

            // GPS button
            SizedBox(
              height: 48,
              child: _fetchingLoc
                  ? Container(
                width: 48,
                decoration: BoxDecoration(
                  color:        AppColors.primaryTint,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.border, width: 1.2),
                ),
                child: const Center(
                  child: SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(
                      color:       AppColors.primary,
                      strokeWidth: 2,
                    ),
                  ),
                ),
              )
                  : GestureDetector(
                onTap: _getCurrentLocation,
                child: Container(
                  width: 48,
                  decoration: BoxDecoration(
                    color:        AppColors.primaryTint,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppColors.border, width: 1.2),
                  ),
                  child: const Icon(
                    Icons.my_location_rounded,
                    color: AppColors.primary,
                    size:  20,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _miniField({
    required TextEditingController     controller,
    required String                    hint,
    required IconData                  icon,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller:   controller,
      keyboardType: const TextInputType.numberWithOptions(
          decimal: true, signed: true),
      style: const TextStyle(
        color:      AppColors.textPrimary,
        fontSize:   13,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        hintText:  hint,
        hintStyle: const TextStyle(
            color: AppColors.textMuted, fontSize: 12),
        prefixIcon: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Icon(icon, color: AppColors.textMuted, size: 15),
        ),
        prefixIconConstraints:
        const BoxConstraints(minWidth: 36, minHeight: 46),
        filled:    true,
        fillColor: AppColors.bgWhite,
        contentPadding: const EdgeInsets.symmetric(
            vertical: 13, horizontal: 10),
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
          color:   AppColors.error,
          fontSize: 10,
        ),
      ),
      validator: validator,
    );
  }

  // ── Shift row ──────────────────────────────────────────────────────────────
  Widget _buildShiftRow() {
    return Row(
      children: [
        Expanded(
          child: _buildField(
            controller: _startController,
            label:      'Start Time',
            hint:       'HH:MM',
            icon:       Icons.login_rounded,
            validator:  _required,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildField(
            controller: _endController,
            label:      'End Time',
            hint:       'HH:MM',
            icon:       Icons.logout_rounded,
            validator:  _required,
          ),
        ),
      ],
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  Widget _fieldLabel(String text) => Text(
    text,
    style: TextStyle(
      fontSize:   12.5,
      fontWeight: FontWeight.w600,
      color:      AppColors.textSecondary,
      letterSpacing: 0.2,
    ),
  );

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'This field is required' : null;
}
