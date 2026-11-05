import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:attendance_app/core/di/injection.dart';
import 'package:attendance_app/core/error/app_exception.dart';
import 'package:attendance_app/core/theme/app_colors.dart';
import 'package:attendance_app/core/theme/app_spacing.dart';
import 'package:attendance_app/core/widgets/app_button.dart';
import 'package:attendance_app/core/widgets/app_card.dart';
import 'package:attendance_app/core/widgets/entity_tile.dart';
import 'package:attendance_app/core/widgets/section_header.dart';
import 'package:attendance_app/core/widgets/status_badge.dart';
import 'package:attendance_app/domain/repositories/employee_repository.dart';
import 'package:attendance_app/domain/repositories/onboarding_repository.dart';
import 'package:attendance_app/features/admin/bulk_upload_screen.dart';
import 'package:attendance_app/features/admin/company_qr_screen.dart';
import 'package:attendance_app/features/admin/invite_person_screen.dart';
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

  Future<void> _open(Uri uri) async {
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No app on this phone can open that')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final prov = Provider.of<UserProvider>(context);
    final company = prov.company;
    final companyId = company?.id ?? '';
    final code = company?.employeeCode ?? '';
    final name = company?.name ?? 'our team';
    final message = inviteMessage(name, code);
    final colors = context.colors;
    final mainSite = prov.sites.where((s) => s.isMain).firstOrNull;
    void open(Widget page) =>
        Navigator.push(context, MaterialPageRoute(builder: (_) => page));

    Widget share(String label, IconData icon, VoidCallback onTap) => Expanded(
      child: AppButton(
        label: label,
        icon: icon,
        size: AppButtonSize.small,
        variant: AppButtonVariant.secondary,
        onPressed: code.isEmpty ? null : onTap,
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add your team'),
        actions: [
          if (!Navigator.of(context).canPop())
            TextButton(
              onPressed: () => Navigator.maybePop(context),
              child: const Text('Later'),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.xxl,
        ),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Company invite code',
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const StatusBadge(
                      status: 'present',
                      label: 'Active',
                      dot: false,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: SelectableText(
                        CompanyQrScreen.pretty(code),
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 4,
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                    AppButton(
                      label: 'Copy',
                      size: AppButtonSize.small,
                      expand: false,
                      variant: AppButtonVariant.secondary,
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: code));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Code copied')),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    share(
                      'QR',
                      Icons.qr_code_2_rounded,
                      () => open(const CompanyQrScreen()),
                    ),
                    const SizedBox(width: 6),
                    share(
                      'WhatsApp',
                      Icons.chat_outlined,
                      () => _open(
                        Uri.parse(
                          'https://wa.me/?text=${Uri.encodeComponent(message)}',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    share(
                      'SMS',
                      Icons.sms_outlined,
                      () => _open(
                        Uri(scheme: 'sms', queryParameters: {'body': message}),
                      ),
                    ),
                    const SizedBox(width: 6),
                    share(
                      'More',
                      Icons.ios_share_rounded,
                      () => SharePlus.instance.share(
                        ShareParams(
                          subject: 'Join $name on PunchIn',
                          text: message,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Employees type this code or scan the QR (print it for the '
                  'entrance). People who join with it get '
                  '${mainSite == null ? 'your main location' : mainSite.name}'
                  '${company?.settings['approveJoiners'] == true ? ' once you approve them' : ''}. '
                  'You can reset it any time.',
                  style: TextStyle(fontSize: 12, color: colors.textTertiary),
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
                title: 'Upload a spreadsheet',
                subtitle: 'Add everyone at once from Excel or CSV',
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
