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

  // "Ink" dark theme — warm near-black paper stock, not the generic cool slate.
  static const AppColors dark = AppColors(
    brand: Color(0xFF8B85FF), // luminous indigo, legible on ink
    brandSoft: Color(0x1F8B85FF),
    background: Color(0xFF15140F),
    surface: Color(0xFF1E1C16),
    surfaceMuted: Color(0xFF272319),
    border: Color(0xFF35302A),
    textPrimary: Color(0xFFF4F1E9),
    textSecondary: Color(0xFFACA594),
    textTertiary: Color(0xFF79715F),
    success: Color(0xFF5FBE7C),
    warning: Color(0xFFE7B54B),
    danger: Color(0xFFE9705E),
    info: Color(0xFF7FA9E8),
    onBrand: Color(0xFF15140F),
  );

  // "Paper" light theme — warm off-white stock with ink text.
  static const AppColors light = AppColors(
    brand: Color(0xFF3A34C9), // deep confident indigo (not candy #6366F1)
    brandSoft: Color(0x143A34C9),
    background: Color(0xFFF5F2EA),
    surface: Color(0xFFFFFEFB),
    surfaceMuted: Color(0xFFECE7DC),
    border: Color(0xFFE2DCCF),
    textPrimary: Color(0xFF1C1A16),
    textSecondary: Color(0xFF5C574C),
    textTertiary: Color(0xFF8B8473),
    success: Color(0xFF2E7A4B),
    warning: Color(0xFF8F6416),
    danger: Color(0xFFB23A2B),
    info: Color(0xFF345C8C),
    onBrand: Color(0xFFFFFEFB),
  );

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
