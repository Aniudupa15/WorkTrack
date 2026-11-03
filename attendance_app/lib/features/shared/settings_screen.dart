import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:attendance_app/core/theme/app_spacing.dart';
import 'package:attendance_app/core/widgets/app_card.dart';
import 'package:attendance_app/core/widgets/entity_tile.dart';
import 'package:attendance_app/core/widgets/section_header.dart';

/// About the app: privacy policy, open-source licences, and version.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  // Hosted on GitHub Pages (docs/ folder). Update if the Pages URL changes.
  static const privacyUrl =
      'https://aniudupa15.github.io/WorkTrack/privacy-policy.html';
  static const version = '1.2.0';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          const SectionHeader(title: 'About'),
          const SizedBox(height: AppSpacing.sm),
          AppGroup(
            children: [
              EntityTile(
                inGroup: true,
                leading: const IconChip(icon: Icons.shield_outlined),
                title: 'Privacy policy',
                chevron: true,
                onTap: () => launchUrl(
                  Uri.parse(privacyUrl),
                  mode: LaunchMode.externalApplication,
                ),
              ),
              EntityTile(
                inGroup: true,
                leading: const IconChip(icon: Icons.description_outlined),
                title: 'Open-source licences',
                chevron: true,
                onTap: () => showLicensePage(
                  context: context,
                  applicationName: 'PunchIn',
                  applicationVersion: version,
                ),
              ),
              const EntityTile(
                inGroup: true,
                leading: IconChip(icon: Icons.info_outline_rounded),
                title: 'Version',
                trailing: Text(version),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
