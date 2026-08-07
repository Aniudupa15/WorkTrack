import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:attendance_app/core/theme/app_colors.dart';
import 'package:attendance_app/core/theme/app_spacing.dart';
import 'package:attendance_app/core/widgets/app_card.dart';

/// App settings. The app is locked to the Aura "Deep Noir" dark identity, so
/// this is the About surface: privacy policy, open-source licenses, and version.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  // Hosted on GitHub Pages (docs/ folder). Update if the Pages URL changes.
  static const _privacyUrl =
      'https://aniudupa15.github.io/WorkTrack/privacy-policy.html';
  static const _version = '1.0.7 (8)';

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        children: [
          _SectionLabel('ABOUT'),
          const SizedBox(height: AppSpacing.md),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _AboutTile(
                  icon: Icons.shield_outlined,
                  label: 'Privacy policy',
                  onTap: () => launchUrl(
                    Uri.parse(_privacyUrl),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
                Divider(height: 1, color: colors.border),
                _AboutTile(
                  icon: Icons.description_outlined,
                  label: 'Open-source licenses',
                  onTap: () => showLicensePage(
                    context: context,
                    applicationName: 'PunchIn',
                    applicationVersion: _version,
                  ),
                ),
                Divider(height: 1, color: colors.border),
                _AboutTile(
                  icon: Icons.info_outline_rounded,
                  label: 'Version',
                  trailingText: _version,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          Center(
            child: Text(
              'PunchIn',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: context.colors.textTertiary,
        fontSize: 12,
        letterSpacing: 1.4,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _AboutTile extends StatelessWidget {
  const _AboutTile({
    required this.icon,
    required this.label,
    this.onTap,
    this.trailingText,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final String? trailingText;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ListTile(
      leading: Icon(icon, size: 22, color: colors.textSecondary),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      trailing: trailingText != null
          ? Text(
              trailingText!,
              style: TextStyle(color: colors.textTertiary, fontSize: 13),
            )
          : Icon(Icons.chevron_right_rounded, color: colors.textTertiary),
      onTap: onTap,
    );
  }
}
