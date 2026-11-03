import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'app_card.dart';

/// A consistent list row: a leading widget (avatar or icon chip), a title +
/// subtitle stack, and an optional trailing widget (status pill, chevron,
/// actions). Employee rows, attendance rows, and leave rows are all this one
/// component, so list density and alignment never drift between screens.
///
/// Standalone it renders as its own card; set [inGroup] when it sits inside an
/// [AppGroup] so it draws as a plain row between dividers.
class EntityTile extends StatelessWidget {
  const EntityTile({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.dense = false,
    this.inGroup = false,
    this.chevron = false,
  });

  final Widget? leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool dense;
  final bool inGroup;

  /// Shows a trailing chevron (navigational rows) when [trailing] is null.
  final bool chevron;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final trail =
        trailing ??
        (chevron
            ? Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: colors.textTertiary,
              )
            : null);
    final row = Row(
      children: [
        if (leading != null) ...[
          leading!,
          const SizedBox(width: AppSpacing.md),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 15,
                  height: 20 / 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 13,
                    height: 18 / 13,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trail != null) ...[const SizedBox(width: AppSpacing.md), trail],
      ],
    );
    final padding = EdgeInsets.symmetric(
      horizontal: AppSpacing.lg,
      vertical: dense ? AppSpacing.sm : AppSpacing.md,
    );

    if (inGroup) {
      final content = ConstrainedBox(
        constraints: BoxConstraints(minHeight: dense ? 52 : 60),
        child: Padding(padding: padding, child: row),
      );
      if (onTap == null) return content;
      return Material(
        color: Colors.transparent,
        child: InkWell(onTap: onTap, child: content),
      );
    }
    return AppCard(onTap: onTap, padding: padding, child: row);
  }
}

/// A rounded, tinted icon in a square chip — the standard "leading" glyph for
/// rows and quick-action cards when there's no avatar.
class IconChip extends StatelessWidget {
  const IconChip({
    super.key,
    required this.icon,
    this.color,
    this.background,
    this.size = 40,
  });

  final IconData icon;
  final Color? color;
  final Color? background;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final fg = color ?? colors.brand;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color:
            background ??
            (color == null ? colors.brandSoft : fg.withValues(alpha: 0.12)),
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Icon(icon, size: size * 0.5, color: fg),
    );
  }
}
