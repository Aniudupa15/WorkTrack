import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import 'package:attendance_app/core/di/injection.dart';
import 'package:attendance_app/core/error/app_exception.dart';
import 'package:attendance_app/core/theme/app_colors.dart';
import 'package:attendance_app/core/theme/app_spacing.dart';
import 'package:attendance_app/core/widgets/app_button.dart';
import 'package:attendance_app/core/widgets/app_loader.dart';
import 'package:attendance_app/core/widgets/avatar.dart';
import 'package:attendance_app/data/datasources/database_service.dart';
import 'package:attendance_app/data/datasources/notification_service.dart';
import 'package:attendance_app/data/datasources/storage_service.dart';
import 'package:attendance_app/data/models/company_model.dart';
import 'package:attendance_app/data/models/location_model.dart';
import 'package:attendance_app/domain/repositories/onboarding_repository.dart';
import 'package:attendance_app/features/onboarding/join_company_screen.dart';
import 'package:attendance_app/features/onboarding/onboarding_step.dart';
import 'package:attendance_app/features/shared/user_provider.dart';

/// Shown after a phone sign-in that isn't part of a company yet. Claims the
/// details typed before the SMS code (or the admin's phone invite), then walks
/// designs 3.3–3.5: permissions, profile photo, all set.
class JoinTeamScreen extends StatefulWidget {
  const JoinTeamScreen({super.key});

  @override
  State<JoinTeamScreen> createState() => _JoinTeamScreenState();
}

enum _Stage { claiming, failed, permissions, photo, done }

class _JoinTeamScreenState extends State<JoinTeamScreen> {
  final _repo = sl<OnboardingRepository>();
  _Stage _stage = _Stage.claiming;
  String? _error;
  String? _companyId;
  CompanyModel? _company;
  List<LocationModel> _sites = const [];
  String _firstName = '';
  String _fullName = '';
  bool _pending = false;
  bool _busy = false;
  bool _locationOk = false;
  bool _notifyOk = false;
  Uint8List? _photo;

  UserProvider get _prov => Provider.of<UserProvider>(context, listen: false);

  @override
  void initState() {
    super.initState();
    _claim();
  }

  Future<void> _claim() async {
    setState(() {
      _stage = _Stage.claiming;
      _error = null;
    });
    final pending = _prov.pendingJoin;
    try {
      final joined = await _repo.claimJoin(
        code: pending?.code,
        name: pending == null || pending.name.isEmpty ? null : pending.name,
        email: pending?.email,
        employeeNumber: pending?.employeeNumber,
      );
      _prov.pendingJoin = null;
      final cid = joined.companyId;
      _companyId = cid;
      _pending = joined.status == 'pending';
      final name = pending?.name.isNotEmpty == true
          ? pending!.name
          : (FirebaseAuth.instance.currentUser?.displayName ?? '');
      _fullName = name.trim();
      _firstName = _fullName.split(' ').first;
      final db = sl<DatabaseService>();
      try {
        _company = await db.getCompany(cid);
        _sites = await db.getLocationsOnce(cid);
      } catch (_) {
        // Pending approval can hide these; the last step copes without.
      }
      if (mounted) setState(() => _stage = _Stage.permissions);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _stage = _Stage.failed;
        _error = e is AppException ? e.message : 'Couldn’t join';
      });
    }
  }

  Future<void> _askLocation() async {
    if (kIsWeb) {
      // Browsers ask at the first punch.
      setState(() => _locationOk = true);
      return;
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.deniedForever) {
      await Geolocator.openAppSettings();
    }
    if (mounted) {
      setState(
        () => _locationOk =
            perm == LocationPermission.always ||
            perm == LocationPermission.whileInUse,
      );
    }
  }

  Future<void> _askNotifications() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || _companyId == null) return;
    // Shows the system prompt; the token itself can take a while (or never
    // arrive on devices without Play services), so don't wait for it.
    sl<NotificationService>()
        .initialize(
          onToken: (t) =>
              sl<DatabaseService>().saveEmployeeFcmToken(_companyId!, uid, t),
        )
        .catchError((_) {});
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (mounted) setState(() => _notifyOk = true);
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final file = await ImagePicker().pickImage(
      source: source,
      maxWidth: 600,
      imageQuality: 80,
      preferredCameraDevice: CameraDevice.front,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (mounted) setState(() => _photo = bytes);
  }

  Future<void> _savePhoto() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (_photo == null || uid == null || _companyId == null) {
      return setState(() => _stage = _Stage.done);
    }
    setState(() => _busy = true);
    try {
      final url = await sl<StorageService>().uploadAvatarBytes(
        _companyId!,
        uid,
        _photo!,
      );
      await sl<DatabaseService>().updateOwnEmployee(_companyId!, uid, {
        'avatarUrl': url,
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Couldn’t upload the photo — add it from Profile'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _stage = _Stage.done;
        });
      }
    }
  }

  Future<void> _finish() async {
    setState(() => _busy = true);
    await _prov.completeOnboarding();
  }

  @override
  Widget build(BuildContext context) {
    switch (_stage) {
      case _Stage.claiming:
        return const Scaffold(body: AppLoader());
      case _Stage.failed:
        return _failed(context);
      case _Stage.permissions:
        return _permissions(context);
      case _Stage.photo:
        return _photoStep(context);
      case _Stage.done:
        return _allSet(context);
    }
  }

  Widget _failed(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        backgroundColor: colors.surface,
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: () => _prov.signOut(),
            child: const Text('Sign out'),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Icon(Icons.link_off_rounded, size: 40, color: colors.warning),
            const SizedBox(height: AppSpacing.lg),
            const Text(
              'We couldn’t find your company',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              _error ?? 'Ask your manager for the invite code.',
              style: TextStyle(color: colors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: 'Enter an invite code',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const _CodeAfterSignIn()),
              ).then((_) => _claim()),
            ),
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: 'Try again',
              variant: AppButtonVariant.ghost,
              onPressed: _claim,
            ),
          ],
        ),
      ),
    );
  }

  Widget _permissions(BuildContext context) {
    return OnboardingStep(
      step: 2,
      of: 3,
      title: 'Two quick permissions',
      subtitle: const Text(
        'PunchIn needs these to mark your attendance. You can change them '
        'any time in Settings.',
      ),
      content: [
        _PermissionCard(
          icon: Icons.location_on_rounded,
          title: 'Location',
          body:
              'Checked only when you punch in or out, to confirm you’re at '
              'work. Never tracked in the background.',
          granted: _locationOk,
          onAllow: _askLocation,
        ),
        const SizedBox(height: AppSpacing.md),
        _PermissionCard(
          icon: Icons.notifications_rounded,
          title: 'Notifications',
          body: 'A reminder before your shift if you haven’t punched in.',
          granted: _notifyOk,
          optional: true,
          onAllow: _askNotifications,
        ),
      ],
      footer: [
        AppButton(
          label: 'Continue',
          onPressed: () => setState(() => _stage = _Stage.photo),
        ),
      ],
    );
  }

  Widget _photoStep(BuildContext context) {
    final colors = context.colors;
    final name = _fullName.isEmpty ? 'You' : _fullName;
    return OnboardingStep(
      step: 3,
      of: 3,
      onBack: () => setState(() => _stage = _Stage.permissions),
      title: 'Add a profile photo',
      subtitle: const Text(
        'Helps your manager recognise you on the team list.',
      ),
      content: [
        const SizedBox(height: AppSpacing.lg),
        Center(
          child: GestureDetector(
            onTap: () => _pickPhoto(ImageSource.camera),
            child: Container(
              width: 128,
              height: 128,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.brandSoft,
                border: Border.all(color: colors.brand, width: 2),
                image: _photo == null
                    ? null
                    : DecorationImage(
                        image: MemoryImage(_photo!),
                        fit: BoxFit.cover,
                      ),
              ),
              child: _photo == null
                  ? Center(child: Avatar(name: name, size: 96))
                  : null,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pickPhoto(ImageSource.camera),
                icon: const Icon(Icons.photo_camera_rounded),
                label: const Text('Take photo'),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pickPhoto(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_rounded),
                label: const Text('Gallery'),
              ),
            ),
          ],
        ),
      ],
      footer: [
        AppButton(
          label: 'Continue',
          loading: _busy,
          onPressed: _busy || _photo == null ? null : _savePhoto,
        ),
        AppButton(
          label: 'Skip for now',
          variant: AppButtonVariant.ghost,
          onPressed: _busy ? null : () => setState(() => _stage = _Stage.done),
        ),
      ],
    );
  }

  Widget _allSet(BuildContext context) {
    final colors = context.colors;
    final c = _company;
    final sites = _sites.map((s) => s.name).join(', ');
    String fmt(String hhmm) {
      final p = hhmm.split(':');
      final h = int.tryParse(p.first) ?? 9;
      final m = p.length > 1 ? p[1] : '00';
      final h12 = h % 12 == 0 ? 12 : h % 12;
      return '$h12:$m ${h < 12 ? 'AM' : 'PM'}';
    }

    Widget row(IconData icon, String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 20, color: colors.brand),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: colors.textSecondary)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 48, 20, 16),
                children: [
                  Center(
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: colors.successSoft,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check_rounded,
                        size: 40,
                        color: colors.success,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    _firstName.isEmpty
                        ? 'You’re all set'
                        : 'You’re all set, $_firstName',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _pending
                        ? 'Your manager will approve you shortly.'
                        : c == null
                        ? 'You’ve joined your team.'
                        : 'You’ve joined ${c.companyName}.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: colors.textSecondary),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  if (c != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: colors.background,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          if (sites.isNotEmpty)
                            row(Icons.location_on_outlined, 'Sites', sites),
                          row(
                            Icons.schedule_rounded,
                            'Shift',
                            '${fmt(c.defaultShiftStart)} – '
                                '${fmt(c.defaultShiftEnd)}',
                          ),
                          if (c.adminName.isNotEmpty)
                            row(
                              Icons.person_outline_rounded,
                              'Manager',
                              c.adminName,
                            ),
                        ],
                      ),
                    ),
                  const SizedBox(height: AppSpacing.lg),
                  if (c?.shiftReminders ?? true)
                    Text(
                      'We’ll remind you 10 minutes before your shift if you '
                      'haven’t punched in.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.textTertiary,
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: AppButton(
                label: 'Go to home',
                loading: _busy,
                onPressed: _busy ? null : _finish,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PermissionCard extends StatelessWidget {
  const _PermissionCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.granted,
    required this.onAllow,
    this.optional = false,
  });

  final IconData icon;
  final String title;
  final String body;
  final bool granted;
  final bool optional;
  final VoidCallback onAllow;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colors.brandSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: colors.brand, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    text: title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    children: [
                      if (optional)
                        TextSpan(
                          text: '  Optional',
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.textTertiary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: TextStyle(fontSize: 13, color: colors.textSecondary),
                ),
                const SizedBox(height: 10),
                granted
                    ? Row(
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            size: 18,
                            color: colors.success,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Allowed',
                            style: TextStyle(
                              color: colors.success,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      )
                    : SizedBox(
                        height: 36,
                        child: FilledButton(
                          onPressed: onAllow,
                          child: const Text('Allow'),
                        ),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Already signed in by phone but no invite matched: collect the code and
/// details, then let [JoinTeamScreen] claim again.
class _CodeAfterSignIn extends StatelessWidget {
  const _CodeAfterSignIn();

  @override
  Widget build(BuildContext context) =>
      const JoinCompanyScreen(afterSignIn: true);
}
