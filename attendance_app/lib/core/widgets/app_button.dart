import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'pressable.dart';

enum AppButtonVariant { primary, secondary, ghost, danger }

enum AppButtonSize { regular, small }

/// One button to rule them all — a single component behind every call to
/// action so height, radius, weight, icon sizing, loading spinner, and press
/// feedback are identical across the app.
///
/// Variants map to intent (primary / secondary / ghost / danger), not to a
/// random pile of ElevatedButton vs OutlinedButton vs TextButton usages.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.regular,
    this.loading = false,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final bool loading;

  /// Stretch to fill the available width.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final small = size == AppButtonSize.small;
    final enabled = onPressed != null && !loading;

    late final Color bg;
    late final Color fg;
    late final Color? borderColor;
    switch (variant) {
      case AppButtonVariant.primary:
        bg = colors.brand;
        fg = colors.onBrand;
        borderColor = null;
      case AppButtonVariant.secondary:
        bg = colors.surface;
        fg = colors.textPrimary;
        borderColor = colors.border;
      case AppButtonVariant.ghost:
        bg = Colors.transparent;
        fg = colors.brand;
        borderColor = null;
      case AppButtonVariant.danger:
        bg = colors.danger.withValues(alpha: 0.12);
        fg = colors.danger;
        borderColor = null;
    }

    final height = small ? 40.0 : 52.0;
    final radius = small ? AppRadius.md : AppRadius.lg;
    final hpad = small ? AppSpacing.lg : AppSpacing.xl;

    final content = loading
        ? SizedBox(
            width: small ? 16 : 20,
            height: small ? 16 : 20,
            child: CircularProgressIndicator(strokeWidth: 2.4, color: fg),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: small ? 16 : 18, color: fg),
                SizedBox(width: small ? 6 : AppSpacing.sm),
              ],
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: fg,
                    fontSize: small ? 13 : 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          );

    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Pressable(
        onTap: enabled ? onPressed : null,
        borderRadius: BorderRadius.circular(radius),
        child: Container(
          height: height,
          width: expand ? double.infinity : null,
          padding: EdgeInsets.symmetric(horizontal: hpad),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(radius),
            border: borderColor != null ? Border.all(color: borderColor) : null,
          ),
          child: content,
        ),
      ),
    );
  }
}
