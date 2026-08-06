import 'package:flutter/material.dart';

/// Semantic color tokens for the app, exposed as a [ThemeExtension] so that
/// light and dark themes provide the *same* names with different values.
///
/// Screens read colors via `context.colors.<token>` and never hard-code hex,
/// which is what makes a single light/dark switch possible.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.brand,
    required this.brandSoft,
    required this.background,
    required this.surface,
    required this.surfaceMuted,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.success,
    required this.warning,
    required this.danger,
    required this.info,
    required this.onBrand,
  });

  /// Primary brand accent (indigo) — the app's identity color.
  final Color brand;

  /// Low-emphasis brand tint for chips, selected states, and icon backdrops.
  final Color brandSoft;

  /// Scaffold background.
  final Color background;

  /// Card / sheet surface.
  final Color surface;

  /// Inset surface (nested panels, list backdrops).
  final Color surfaceMuted;

  /// Hairline borders and dividers.
  final Color border;

  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;

  final Color success;
  final Color warning;
  final Color danger;
  final Color info;

  /// Foreground on top of [brand].
  final Color onBrand;

  // "Deep Noir" dark theme (Aura) — a warm off-black base with tonal layers,
  // a lavender primary, and teal reserved for success. OLED-ready: hierarchy
  // comes from surface brightness, not shadows.
  static const AppColors dark = AppColors(
    brand: Color(0xFFCEBDFF), // lavender primary
    brandSoft: Color(0x24CEBDFF), // ~14% lavender wash
    background: Color(0xFF131313),
    surface: Color(0xFF1C1B1B), // Level-1 card
    surfaceMuted: Color(0xFF201F1F), // inset panels / fields
    border: Color(0xFF302E36), // subtle warm hairline
    textPrimary: Color(0xFFE5E2E1), // on-surface
    textSecondary: Color(0xFFCAC4D4), // on-surface-variant
    textTertiary: Color(0xFF948E9D), // outline
    success: Color(0xFF44E2CD), // teal — "Checked In"
    warning: Color(0xFFF2C26B), // amber — late / pending (functional accent)
    danger: Color(0xFFFFB4AB), // error
    info: Color(0xFFA9C7FF), // periwinkle — info / half-day
    onBrand: Color(0xFF381385), // dark text on lavender
  );

  // Light counterpart in the same lavender/teal/rose family, so the toggle
  // still reads as "Aura" rather than a different product. Derived from Aura's
  // inverse / fixed tokens (inverse-primary #674BB5).
  static const AppColors light = AppColors(
    brand: Color(0xFF674BB5), // inverse-primary lavender
    brandSoft: Color(0x14674BB5),
    background: Color(0xFFF6F4F2),
    surface: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFEFECF4),
    border: Color(0xFFE4E0EA),
    textPrimary: Color(0xFF1C1B1F),
    textSecondary: Color(0xFF49454E),
    textTertiary: Color(0xFF7A7580),
    success: Color(0xFF0F766E), // deep teal, legible on light
    warning: Color(0xFF9A6B12),
    danger: Color(0xFFB3261E),
    info: Color(0xFF3B5BDB),
    onBrand: Color(0xFFFFFFFF),
  );

  /// Returns a foreground (near-black or white) that stays legible on top of a
  /// solid [c] — used for buttons/markers painted in a state colour, since those
  /// colours are light in the dark theme and dark in the light theme.
  static Color onColor(Color c) =>
      c.computeLuminance() > 0.5 ? const Color(0xFF201F1F) : Colors.white;

  /// Returns the status color for an attendance/leave status string.
  Color statusColor(String status) {
    switch (status) {
      case 'present':
      case 'approved':
        return success;
      case 'late':
      case 'pending':
        return warning;
      case 'absent':
      case 'rejected':
        return danger;
      default:
        return info;
    }
  }

  @override
  AppColors copyWith({
    Color? brand,
    Color? brandSoft,
    Color? background,
    Color? surface,
    Color? surfaceMuted,
    Color? border,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? success,
    Color? warning,
    Color? danger,
    Color? info,
    Color? onBrand,
  }) {
    return AppColors(
      brand: brand ?? this.brand,
      brandSoft: brandSoft ?? this.brandSoft,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      border: border ?? this.border,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      info: info ?? this.info,
      onBrand: onBrand ?? this.onBrand,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      brand: Color.lerp(brand, other.brand, t)!,
      brandSoft: Color.lerp(brandSoft, other.brandSoft, t)!,
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t)!,
      border: Color.lerp(border, other.border, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      info: Color.lerp(info, other.info, t)!,
      onBrand: Color.lerp(onBrand, other.onBrand, t)!,
    );
  }
}

/// Ergonomic access: `context.colors.brand`.
extension AppColorsX on BuildContext {
  AppColors get colors =>
      Theme.of(this).extension<AppColors>() ?? AppColors.dark;
}
