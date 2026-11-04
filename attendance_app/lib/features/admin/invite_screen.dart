import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import 'package:attendance_app/core/di/injection.dart';
import 'package:attendance_app/core/error/app_exception.dart';
import 'package:attendance_app/core/theme/app_colors.dart';
import 'package:attendance_app/core/theme/app_spacing.dart';
import 'package:attendance_app/core/widgets/app_button.dart';
import 'package:attendance_app/core/widgets/app_card.dart';
import 'package:attendance_app/core/widgets/entity_tile.dart';
import 'package:attendance_app/core/widgets/section_header.dart';
import 'package:attendance_app/domain/repositories/employee_repository.dart';
import 'package:attendance_app/domain/repositories/onboarding_repository.dart';
import 'package:attendance_app/features/admin/bulk_upload_screen.dart';
import 'package:attendance_app/features/admin/invite_person_screen.dart';
import 'package:attendance_app/features/onboarding/qr_scan_screen.dart';
import 'package:attendance_app/features/shared/user_provider.dart';

/// Everything for growing the team: the join code and its QR, inviting by
/// phone (one person or a whole sheet), and invites not yet claimed.
class InviteScreen extends StatefulWidget {
  const InviteScreen({super.key});

  @override
  State<InviteScreen> createState() => _InviteScreenState();
}

class _InviteScreenState extends State<InviteScreen> {
  bool _resetting = false;

  Future<void> _reset(String companyId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset the company code?'),
        content: const Text(
          'The current code and QR stop working right away. People already '
          'on your team aren’t affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final prov = Provider.of<UserProvider>(context, listen: false);
    setState(() => _resetting = true);
    try {
      await sl<OnboardingRepository>().resetJoinCode(companyId);
      await prov.refreshUser();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e is AppException ? e.message : 'Couldn’t reset'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _resetting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final prov = Provider.of<UserProvider>(context);
    final company = prov.company;
    final companyId = company?.id ?? '';
    final code = company?.employeeCode ?? '';
    final name = company?.name ?? 'our team';
    final colors = context.colors;
    void open(Widget page) =>
        Navigator.push(context, MaterialPageRoute(builder: (_) => page));

    return Scaffold(
      appBar: AppBar(title: const Text('Invite people')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.xxl,
        ),
        children: [
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              children: [
                Text(
                  'Scan to join $name',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.lg),
                if (code.isNotEmpty)
                  QrImageView(
                    data: QrScanScreen.payloadFor(code),
                    size: 200,
                    eyeStyle: QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: colors.textPrimary,
                    ),
                    dataModuleStyle: QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: colors.textPrimary,
                    ),
                  ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'or enter code',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                const SizedBox(height: 4),
                SelectableText(
                  code,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 5,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        label: 'Share',
                        icon: Icons.share_rounded,
                        onPressed: () => SharePlus.instance.share(
                          ShareParams(
                            subject: 'Join $name on PunchIn',
                            text:
                                'Join $name on PunchIn.\n\n'
                                '1. Install PunchIn and tap “Create an account” '
                                '→ “Join my team”.\n'
                                '2. Sign in with your mobile number.\n'
                                '3. Enter company code $code',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: AppButton(
                        label: 'Copy',
                        icon: Icons.copy_rounded,
                        variant: AppButtonVariant.secondary,
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: code));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Code copied')),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: _resetting ? null : () => _reset(companyId),
                  child: Text(_resetting ? 'Resetting…' : 'Reset code'),
                ),
              ],
            ),
          ),
          const SectionHeader(title: 'Invite by phone'),
          const SizedBox(height: AppSpacing.sm),
          AppGroup(
            children: [
              EntityTile(
                inGroup: true,
                leading: const IconChip(icon: Icons.person_add_alt_1_rounded),
                title: 'Add one person',
                subtitle: 'They sign in with this number — no code needed',
                chevron: true,
                onTap: () => open(const InvitePersonScreen()),
              ),
              EntityTile(
                inGroup: true,
                leading: const IconChip(icon: Icons.upload_file_rounded),
                title: 'Upload a list',
                subtitle: 'Excel or CSV with names and phone numbers',
                chevron: true,
                onTap: () => open(const BulkUploadScreen()),
              ),
            ],
          ),
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: sl<EmployeeRepository>().watchInvites(companyId),
            builder: (context, snap) {
              final invites = snap.data ?? const [];
              if (invites.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SectionHeader(
                    title: 'Invited, not joined yet (${invites.length})',
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppGroup(
                    children: [
                      for (final i in invites)
                        EntityTile(
                          inGroup: true,
                          title: '${i['name']}',
                          subtitle: [
                            i['phone'],
                            i['department'],
                          ].whereType<String>().join(' · '),
                          trailing: IconButton(
                            tooltip: 'Withdraw invite',
                            icon: Icon(
                              Icons.close_rounded,
                              color: colors.textTertiary,
                            ),
                            onPressed: () => sl<EmployeeRepository>()
                                .deleteInvite(i['phone'] as String),
                          ),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
