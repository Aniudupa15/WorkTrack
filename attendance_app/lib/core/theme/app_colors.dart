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

  // Editorial red/black/white — a sharp, high-contrast light identity: white
  // paper, ink text, a single vermilion accent for actions and attention.
  // Present/on-time read as ink; late is grey; absent/rejected are red.
  static const AppColors light = AppColors(
    brand: Color(0xFFE23A1A), // vermilion — primary actions & attention
    brandSoft: Color(0x14E23A1A),
    background: Color(0xFFFFFFFF),
    surface: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFF3F2EF), // inset boxes / fields
    border: Color(0xFFDBD8D2), // clean hairline
    textPrimary: Color(0xFF17150F), // near-black ink
    textSecondary: Color(0xFF57544C),
    textTertiary: Color(0xFF8A867C),
    success: Color(0xFF17150F), // ink — present / on-time / approved
    warning: Color(0xFF8A867C), // grey — late
    danger: Color(0xFFE23A1A), // red — absent / rejected
    info: Color(0xFFB0ACA2), // light grey — half-day
    onBrand: Color(0xFFFFFFFF),
  );

  // Dark counterpart in the same red/ink family (kept coherent; the app is
  // currently locked to the light editorial identity).
  static const AppColors dark = AppColors(
    brand: Color(0xFFFF4A2E),
    brandSoft: Color(0x1FFF4A2E),
    background: Color(0xFF0E0E0E),
    surface: Color(0xFF161616),
    surfaceMuted: Color(0xFF1E1E1E),
    border: Color(0xFF2C2C2C),
    textPrimary: Color(0xFFF2F0EA),
    textSecondary: Color(0xFFA8A49B),
    textTertiary: Color(0xFF736F66),
    success: Color(0xFFF2F0EA), // ink→light for present/on-time on dark
    warning: Color(0xFF8A867C),
    danger: Color(0xFFFF4A2E),
    info: Color(0xFF6B6B6B),
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
