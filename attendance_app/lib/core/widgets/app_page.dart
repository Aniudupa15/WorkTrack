import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// The large left-aligned title used at the top of tab screens ("Attendance",
/// "Team", "Reports"), with optional trailing actions. Use as a
/// [Scaffold.appBar].
class TabHeader extends StatelessWidget implements PreferredSizeWidget {
  const TabHeader({super.key, required this.title, this.actions = const []});

  final String title;
  final List<Widget> actions;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.sm,
        ),
        child: Row(
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 26,
                    height: 32 / 26,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                    color: colors.textPrimary,
                  ),
                ),
              ),
            ),
            ...actions,
          ],
        ),
      ),
    );
  }
}

/// A soft teal (or amber / red) message strip with a leading icon.
class AppBanner extends StatelessWidget {
  const AppBanner({
    super.key,
    required this.child,
    this.icon = Icons.info_outline_rounded,
    this.tone = BannerTone.brand,
    this.onTap,
  });

  final Widget child;
  final IconData icon;
  final BannerTone tone;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (bg, fg) = switch (tone) {
      BannerTone.brand => (c.brandSoft, c.brandStrong),
      BannerTone.warning => (c.warningSoft, c.warning),
      BannerTone.danger => (c.dangerSoft, c.danger),
    };
    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: fg),
          const SizedBox(width: 10),
          Expanded(
            child: DefaultTextStyle.merge(
              style: TextStyle(fontSize: 13, height: 18 / 13, color: fg),
              child: child,
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return content;
    return GestureDetector(onTap: onTap, child: content);
  }
}

enum BannerTone { brand, warning, danger }
