import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import 'package:attendance_app/core/di/injection.dart';
import 'package:attendance_app/core/error/app_exception.dart';
import 'package:attendance_app/core/theme/app_colors.dart';
import 'package:attendance_app/core/theme/app_spacing.dart';
import 'package:attendance_app/core/widgets/app_button.dart';
import 'package:attendance_app/core/widgets/app_card.dart';
import 'package:attendance_app/core/widgets/avatar.dart';
import 'package:attendance_app/core/widgets/entity_tile.dart';
import 'package:attendance_app/domain/repositories/company_repository.dart';
import 'package:attendance_app/domain/repositories/onboarding_repository.dart';
import 'package:attendance_app/features/onboarding/qr_scan_screen.dart';
import 'package:attendance_app/features/shared/user_provider.dart';

/// The company's join QR: share it, print it as a poster for the entrance,
/// choose whether joiners need approval, or reset the code.
class CompanyQrScreen extends StatefulWidget {
  const CompanyQrScreen({super.key});

  /// "BRT7K4Q" → "BRT-7K4Q".
  static String pretty(String code) => code.length == 7 && !code.contains('-')
      ? '${code.substring(0, 3)}-${code.substring(3)}'
      : code;

  @override
  State<CompanyQrScreen> createState() => _CompanyQrScreenState();
}

class _CompanyQrScreenState extends State<CompanyQrScreen> {
  final _poster = GlobalKey();
  bool _busy = false;

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _setApproval(bool on) async {
    final prov = Provider.of<UserProvider>(context, listen: false);
    final company = prov.company;
    if (company == null) return;
    try {
      await sl<CompanyRepository>().updateSettings(company.id, {
        ...company.settings,
        'approveJoiners': on,
      });
      await prov.refreshUser();
    } catch (_) {
      _snack('Couldn’t change that setting');
    }
  }

  Future<void> _reset() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Reset the company code?'),
        content: const Text(
          'The current code and QR stop working right away — reprint any '
          'posters. People already on your team aren’t affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(d, true),
            child: Text(
              'Reset',
              style: TextStyle(color: context.colors.danger),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final prov = Provider.of<UserProvider>(context, listen: false);
    setState(() => _busy = true);
    try {
      await sl<OnboardingRepository>().resetJoinCode(prov.company!.id);
      await prov.refreshUser();
    } catch (e) {
      _snack(e is AppException ? e.message : 'Couldn’t reset');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Renders the poster card to a PNG and hands it to the share sheet, from
  /// where it can be printed, saved or sent.
  Future<void> _sharePoster(String name) async {
    final boundary =
        _poster.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return;
    try {
      final image = await boundary.toImage(pixelRatio: 4);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) return;
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              bytes.buffer.asUint8List(),
              name: 'punchin-join-poster.png',
              mimeType: 'image/png',
            ),
          ],
          subject: 'Join $name on PunchIn',
        ),
      );
    } catch (_) {
      _snack('Couldn’t make the poster');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final company = Provider.of<UserProvider>(context).company;
    final code = company?.employeeCode ?? '';
    final name = company?.name ?? 'your company';
    final approve = company?.settings['approveJoiners'] == true;

    return Scaffold(
      appBar: AppBar(title: const Text('Join with QR')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.xxl,
        ),
        children: [
          RepaintBoundary(
            key: _poster,
            child: AppCard(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Avatar(name: name, square: true),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                            Text(
                              'Scan with the PunchIn app to join',
                              style: TextStyle(
                                fontSize: 12,
                                color: colors.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(color: colors.border),
                    ),
                    child: code.isEmpty
                        ? const SizedBox(width: 216, height: 216)
                        : QrImageView(
                            data: QrScanScreen.payloadFor(code),
                            size: 216,
                            padding: EdgeInsets.zero,
                            backgroundColor: Colors.white,
                            eyeStyle: const QrEyeStyle(
                              eyeShape: QrEyeShape.square,
                              color: Color(0xFF111827),
                            ),
                            dataModuleStyle: const QrDataModuleStyle(
                              dataModuleShape: QrDataModuleShape.square,
                              color: Color(0xFF111827),
                            ),
                            semanticsLabel:
                                'QR code for invite code '
                                '${CompanyQrScreen.pretty(code)}',
                          ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Or enter code',
                    style: TextStyle(fontSize: 12, color: colors.textTertiary),
                  ),
                  Text(
                    CompanyQrScreen.pretty(code),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 4,
                      color: colors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppGroup(
            children: [
              SwitchListTile(
                value: approve,
                onChanged: _setApproval,
                title: const Text(
                  'Ask admin to approve joiners',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
                subtitle: const Text(
                  'New people wait until you accept them',
                  style: TextStyle(fontSize: 13),
                ),
              ),
              EntityTile(
                inGroup: true,
                title: _busy ? 'Resetting…' : 'Reset code',
                titleColor: colors.danger,
                subtitle: 'Old QR and code stop working',
                onTap: _busy ? null : _reset,
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Print poster',
                  icon: Icons.print_outlined,
                  variant: AppButtonVariant.secondary,
                  onPressed: code.isEmpty ? null : () => _sharePoster(name),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppButton(
                  label: 'Share',
                  icon: Icons.ios_share_rounded,
                  onPressed: code.isEmpty
                      ? null
                      : () => SharePlus.instance.share(
                          ShareParams(
                            subject: 'Join $name on PunchIn',
                            text: inviteMessage(name, code),
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The text people get by WhatsApp, SMS or the share sheet.
String inviteMessage(String company, String code) =>
    'Join $company on PunchIn to mark your attendance.\n\n'
    '1. Install PunchIn: https://play.google.com/store/apps/details?id=com.aniudupa.punchin\n'
    '2. Tap “Join with an invite code” and enter '
    '${CompanyQrScreen.pretty(code)}\n'
    '3. Verify your mobile number — that’s it.';
