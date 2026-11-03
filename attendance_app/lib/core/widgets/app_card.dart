import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'pressable.dart';

/// The canonical surface in the app: a white, rounded card with a hairline
/// border and a soft shadow on the grey screen background. Every card-shaped
/// thing (dashboard tiles, info panels) is built from this so radius, border,
/// padding, and press behaviour stay identical everywhere.
///
/// Pass [onTap] to make it interactive — it then animates on press via
/// [Pressable]. [elevated] swaps the resting shadow for the raised one used by
/// floating panels (map overlays).
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.radius = AppRadius.lg,
    this.color,
    this.border = true,
    this.elevated = false,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? color;
  final bool border;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final surface = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? colors.surface,
        borderRadius: BorderRadius.circular(radius),
        border: border ? Border.all(color: colors.border) : null,
        boxShadow: dark
            ? null
            : (elevated ? AppShadows.raised : AppShadows.card),
      ),
      child: child,
    );

    if (onTap == null) return surface;
    return Pressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(radius),
      child: surface,
    );
  }
}

/// A card that stacks related rows separated by hairline dividers — the
/// settings-list / grouped-table pattern used for most lists in the app.
class AppGroup extends StatelessWidget {
  const AppGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AppCard(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) Divider(height: 1, color: colors.border),
              children[i],
            ],
          ],
        ),
      ),
    );
  }
}
