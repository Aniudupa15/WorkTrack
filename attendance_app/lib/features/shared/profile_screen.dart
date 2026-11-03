import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:attendance_app/core/theme/app_colors.dart';
import 'package:attendance_app/core/theme/app_spacing.dart';
import 'package:attendance_app/core/utils/attendance_clock.dart';
import 'package:attendance_app/core/widgets/app_card.dart';
import 'package:attendance_app/core/widgets/app_page.dart';
import 'package:attendance_app/core/widgets/avatar.dart';
import 'package:attendance_app/core/widgets/entity_tile.dart';
import 'package:attendance_app/core/widgets/section_header.dart';
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
      user.department,
      user.position,
    ].whereType<String>().where((s) => s.isNotEmpty).join(' · ');

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
                  title: 'Work location',
                  subtitle: user.workAddress ?? 'Not assigned yet',
                ),
                EntityTile(
                  inGroup: true,
                  leading: const IconChip(icon: Icons.schedule_rounded),
                  title: 'Shift',
                  subtitle:
                      '${AttendanceClock.formatShiftTime(user.shiftStart)} – '
                      '${AttendanceClock.formatShiftTime(user.shiftEnd)}',
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
}
