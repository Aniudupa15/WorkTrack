import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'pressable.dart';

/// The canonical surface in the app: a bordered, rounded panel on
/// [AppColors.surface]. Every card-shaped thing (dashboard tiles, list rows,
/// info panels) is built from this so radius, border, padding, and press
/// behaviour stay identical everywhere.
///
/// Pass [onTap] to make it interactive — it then animates on press via
/// [Pressable]. In light mode an optional soft shadow adds quiet depth; in dark
/// mode the hairline border alone defines the edge (shadows read as muddy on
/// near-black, so they're suppressed).
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(AppSpacing.xl),
    this.radius = AppRadius.xl,
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

  /// Adds a soft drop shadow in light mode for a subtle lift.
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? colors.surface,
        borderRadius: BorderRadius.circular(radius),
        border: border ? Border.all(color: colors.border) : null,
        boxShadow: elevated && !isDark
            ? [
                BoxShadow(
                  color: const Color(0xFF101828).withValues(alpha: 0.05),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
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
