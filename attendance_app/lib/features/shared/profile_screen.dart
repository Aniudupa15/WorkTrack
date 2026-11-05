import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:attendance_app/core/di/injection.dart';
import 'package:attendance_app/core/error/app_exception.dart';
import 'package:attendance_app/core/theme/app_colors.dart';
import 'package:attendance_app/core/theme/app_spacing.dart';
import 'package:attendance_app/core/utils/attendance_clock.dart';
import 'package:attendance_app/core/widgets/app_card.dart';
import 'package:attendance_app/core/widgets/app_page.dart';
import 'package:attendance_app/core/widgets/avatar.dart';
import 'package:attendance_app/core/widgets/entity_tile.dart';
import 'package:attendance_app/core/widgets/section_header.dart';
import 'package:attendance_app/data/datasources/database_service.dart';
import 'package:attendance_app/domain/repositories/onboarding_repository.dart';
import 'package:attendance_app/features/shared/settings_screen.dart';
import 'package:attendance_app/features/shared/user_provider.dart';

/// The signed-in user's profile: who they are, where and when they work, and
/// account actions (privacy, licences, sign out).
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final prov = Provider.of<UserProvider>(context);
    final user = prov.user;
    final colors = context.colors;
    if (user == null) return const Scaffold(body: SizedBox.shrink());

    final subtitle = [
      user.department ?? user.position,
      user.employeeNumber,
    ].whereType<String>().where((s) => s.isNotEmpty).join(' · ');
    final isEmployee = user.role == 'employee';
    final remindersOn =
        !user.remindersOff && (prov.company?.shiftReminders ?? true);

    return Scaffold(
      appBar: Navigator.of(context).canPop()
          ? AppBar(title: const Text('Profile'))
          : const TabHeader(title: 'Profile'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.xs,
          AppSpacing.lg,
          AppSpacing.xxl,
        ),
        children: [
          AppCard(
            child: Row(
              children: [
                Avatar(name: user.name, size: 64, imageUrl: user.avatarUrl),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      if (subtitle.isNotEmpty)
                        Text(
                          subtitle,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      if (prov.company?.name.isNotEmpty ?? false)
                        Text(
                          prov.company!.name,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SectionHeader(title: 'Details'),
          const SizedBox(height: AppSpacing.sm),
          AppGroup(
            children: [
              if (user.email.isNotEmpty || user.phone == null)
                EntityTile(
                  inGroup: true,
                  leading: const IconChip(icon: Icons.mail_outline_rounded),
                  title: 'Email',
                  subtitle: user.email.isEmpty ? 'Not set' : user.email,
                ),
              if (user.phone != null)
                EntityTile(
                  inGroup: true,
                  leading: const IconChip(icon: Icons.phone_outlined),
                  title: 'Phone',
                  subtitle: user.phone,
                ),
              if (user.role == 'employee') ...[
                EntityTile(
                  inGroup: true,
                  leading: const IconChip(icon: Icons.location_on_outlined),
                  title: prov.sites.length > 1
                      ? 'Work locations'
                      : 'Work location',
                  subtitle: prov.sites.isEmpty
                      ? 'Not assigned yet'
                      : prov.sites.map((s) => s.name).join(', '),
                ),
                EntityTile(
                  inGroup: true,
                  leading: const IconChip(icon: Icons.schedule_rounded),
                  title: 'Shift',
                  subtitle:
                      '${AttendanceClock.formatShiftTime(user.shiftStart)} – '
                      '${AttendanceClock.formatShiftTime(user.shiftEnd)}',
                ),
                SwitchListTile(
                  secondary: const IconChip(
                    icon: Icons.notifications_none_rounded,
                  ),
                  title: const Text(
                    'Shift reminders',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  subtitle: Text(
                    prov.company?.shiftReminders == false
                        ? 'Turned off by your company'
                        : 'Before your shift, and if you forget to check out',
                    style: const TextStyle(fontSize: 13),
                  ),
                  value: remindersOn,
                  onChanged: prov.company?.shiftReminders == false
                      ? null
                      : (on) => _setReminders(context, prov, on),
                ),
              ],
              if (user.role == 'admin')
                EntityTile(
                  inGroup: true,
                  leading: const IconChip(icon: Icons.verified_user_outlined),
                  title: 'Role',
                  subtitle: 'Company administrator',
                ),
            ],
          ),
          const SectionHeader(title: 'Account'),
          const SizedBox(height: AppSpacing.sm),
          AppGroup(
            children: [
              EntityTile(
                inGroup: true,
                title: 'Privacy policy',
                chevron: true,
                onTap: () => launchUrl(
                  Uri.parse(SettingsScreen.privacyUrl),
                  mode: LaunchMode.externalApplication,
                ),
              ),
              EntityTile(
                inGroup: true,
                title: 'Open-source licences',
                chevron: true,
                onTap: () => showLicensePage(
                  context: context,
                  applicationName: 'PunchIn',
                  applicationVersion: SettingsScreen.version,
                ),
              ),
              EntityTile(
                inGroup: true,
                title: 'Help & support',
                chevron: true,
                onTap: () => launchUrl(
                  Uri.parse(
                    'mailto:${SettingsScreen.supportEmail}'
                    '?subject=PunchIn%20help',
                  ),
                ),
              ),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => prov.signOut(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: 18,
                    ),
                    child: Row(
                      children: [
                        Text(
                          'Sign out',
                          style: TextStyle(
                            color: colors.danger,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (isEmployee) ...[
            const SizedBox(height: AppSpacing.md),
            AppGroup(
              children: [
                EntityTile(
                  inGroup: true,
                  title: 'Delete account',
                  titleColor: colors.danger,
                  onTap: () => _deleteAccount(context, prov),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          Center(
            child: Text(
              'PunchIn ${SettingsScreen.version}',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _setReminders(
    BuildContext context,
    UserProvider prov,
    bool on,
  ) async {
    final user = prov.user!;
    try {
      await sl<DatabaseService>().updateOwnEmployee(prov.company!.id, user.id, {
        'remindersOff': !on,
      });
      await prov.refreshUser();
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Couldn’t change reminders')),
        );
      }
    }
  }

  Future<void> _deleteAccount(BuildContext context, UserProvider prov) async {
    final colors = context.colors;
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Delete your account?'),
        content: Text(
          'This removes your profile, attendance history, leave requests, '
          'photo and selfies, takes you out of '
          '${prov.company?.name ?? 'your company'} and deletes your login. '
          'Ask your manager for any records you need first.\n\n'
          'This can’t be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(d, true),
            child: Text('Delete', style: TextStyle(color: colors.danger)),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await sl<OnboardingRepository>().deleteMyAccount();
      await prov.signOut();
      messenger.showSnackBar(
        const SnackBar(content: Text('Your account was deleted')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            e is AppException ? e.message : 'Couldn’t delete your account',
          ),
        ),
      );
    }
  }
}
