import 'package:flutter/material.dart';

/// Semantic color tokens for the app, exposed as a [ThemeExtension] so that
/// light and dark themes provide the *same* names with different values.
///
/// Screens read colors via `context.colors.<token>` and never hard-code hex,
/// which is what makes a single light/dark switch possible. Values mirror the
/// PunchIn design system (v2) `tokens.json`.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.brand,
    required this.brandStrong,
    required this.brandSoft,
    required this.brandMuted,
    required this.background,
    required this.surface,
    required this.surfaceMuted,
    required this.border,
    required this.borderStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.success,
    required this.successSoft,
    required this.warning,
    required this.warningSoft,
    required this.danger,
    required this.dangerSoft,
    required this.info,
    required this.infoSoft,
    required this.onBrand,
  });

  /// Teal — primary buttons, active tab, links, the geofence ring.
  final Color brand;

  /// Pressed state of brand fills; brand text on [brandSoft].
  final Color brandStrong;

  /// Tinted backgrounds: selected chips, active nav pill, info banners.
  final Color brandSoft;

  /// Borders of selected cards and the geofence fill.
  final Color brandMuted;

  /// Screen background behind cards (soft grey).
  final Color background;

  /// Cards, sheets, inputs, app bars, bottom nav.
  final Color surface;

  /// Inset areas inside a card: segmented controls, summary rows, tracks.
  final Color surfaceMuted;

  /// Card outlines, dividers, inputs at rest.
  final Color border;

  /// Secondary button outline, dashed upload areas.
  final Color borderStrong;

  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;

  /// Present / on time / approved.
  final Color success;
  final Color successSoft;

  /// Late / pending.
  final Color warning;
  final Color warningSoft;

  /// Absent / rejected / errors / destructive.
  final Color danger;
  final Color dangerSoft;

  /// Leave / holiday / neutral information.
  final Color info;
  final Color infoSoft;

  /// Foreground on top of [brand].
  final Color onBrand;

  static const AppColors light = AppColors(
    brand: Color(0xFF0F766E),
    brandStrong: Color(0xFF115E59),
    brandSoft: Color(0xFFF0FDFA),
    brandMuted: Color(0xFFCCFBF1),
    background: Color(0xFFF6F7F6),
    surface: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFF3F4F6),
    border: Color(0xFFE5E7EB),
    borderStrong: Color(0xFFD1D5DB),
    textPrimary: Color(0xFF111827),
    textSecondary: Color(0xFF4B5563),
    textTertiary: Color(0xFF6B7280),
    success: Color(0xFF15803D),
    successSoft: Color(0xFFDCFCE7),
    warning: Color(0xFFB45309),
    warningSoft: Color(0xFFFEF3C7),
    danger: Color(0xFFB91C1C),
    dangerSoft: Color(0xFFFEE2E2),
    info: Color(0xFF1D4ED8),
    infoSoft: Color(0xFFDBEAFE),
    onBrand: Color(0xFFFFFFFF),
  );

  static const AppColors dark = AppColors(
    brand: Color(0xFF2DD4BF),
    brandStrong: Color(0xFF5EEAD4),
    brandSoft: Color(0xFF0F2A27),
    brandMuted: Color(0xFF134E48),
    background: Color(0xFF0B1110),
    surface: Color(0xFF121A19),
    surfaceMuted: Color(0xFF1A2321),
    border: Color(0xFF26302E),
    borderStrong: Color(0xFF36423F),
    textPrimary: Color(0xFFF1F5F4),
    textSecondary: Color(0xFFA7B3B0),
    textTertiary: Color(0xFF7D8A87),
    success: Color(0xFF4ADE80),
    successSoft: Color(0xFF0F2E1B),
    warning: Color(0xFFFBBF24),
    warningSoft: Color(0xFF33270A),
    danger: Color(0xFFF87171),
    dangerSoft: Color(0xFF3A1414),
    info: Color(0xFF93C5FD),
    infoSoft: Color(0xFF14213D),
    onBrand: Color(0xFF042F2C),
  );

  /// Returns a foreground (near-black or white) that stays legible on top of a
  /// solid [c].
  static Color onColor(Color c) =>
      c.computeLuminance() > 0.5 ? const Color(0xFF111827) : Colors.white;

  /// Strong (text/icon) color for an attendance/leave status string.
  Color statusColor(String status) => _status(status).$1;

  /// Soft (pill background) color for an attendance/leave status string.
  Color statusSoftColor(String status) => _status(status).$2;

  (Color, Color) _status(String status) {
    switch (status) {
      case 'present':
      case 'approved':
      case 'active':
      case 'on_time':
        return (success, successSoft);
      case 'late':
      case 'pending':
        return (warning, warningSoft);
      case 'absent':
      case 'rejected':
      case 'inactive':
      case 'suspended':
        return (danger, dangerSoft);
      case 'leave':
      case 'holiday':
      case 'half_day':
        return (info, infoSoft);
      default:
        return (textSecondary, surfaceMuted);
    }
  }

  @override
  AppColors copyWith({
    Color? brand,
    Color? brandStrong,
    Color? brandSoft,
    Color? brandMuted,
    Color? background,
    Color? surface,
    Color? surfaceMuted,
    Color? border,
    Color? borderStrong,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? success,
    Color? successSoft,
    Color? warning,
    Color? warningSoft,
    Color? danger,
    Color? dangerSoft,
    Color? info,
    Color? infoSoft,
    Color? onBrand,
  }) {
    return AppColors(
      brand: brand ?? this.brand,
      brandStrong: brandStrong ?? this.brandStrong,
      brandSoft: brandSoft ?? this.brandSoft,
      brandMuted: brandMuted ?? this.brandMuted,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      border: border ?? this.border,
      borderStrong: borderStrong ?? this.borderStrong,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      success: success ?? this.success,
      successSoft: successSoft ?? this.successSoft,
      warning: warning ?? this.warning,
      warningSoft: warningSoft ?? this.warningSoft,
      danger: danger ?? this.danger,
      dangerSoft: dangerSoft ?? this.dangerSoft,
      info: info ?? this.info,
      infoSoft: infoSoft ?? this.infoSoft,
      onBrand: onBrand ?? this.onBrand,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppColors(
      brand: l(brand, other.brand),
      brandStrong: l(brandStrong, other.brandStrong),
      brandSoft: l(brandSoft, other.brandSoft),
      brandMuted: l(brandMuted, other.brandMuted),
      background: l(background, other.background),
      surface: l(surface, other.surface),
      surfaceMuted: l(surfaceMuted, other.surfaceMuted),
      border: l(border, other.border),
      borderStrong: l(borderStrong, other.borderStrong),
      textPrimary: l(textPrimary, other.textPrimary),
      textSecondary: l(textSecondary, other.textSecondary),
      textTertiary: l(textTertiary, other.textTertiary),
      success: l(success, other.success),
      successSoft: l(successSoft, other.successSoft),
      warning: l(warning, other.warning),
      warningSoft: l(warningSoft, other.warningSoft),
      danger: l(danger, other.danger),
      dangerSoft: l(dangerSoft, other.dangerSoft),
      info: l(info, other.info),
      infoSoft: l(infoSoft, other.infoSoft),
      onBrand: l(onBrand, other.onBrand),
    );
  }
}

/// Ergonomic access: `context.colors.brand`.
extension AppColorsX on BuildContext {
  AppColors get colors =>
      Theme.of(this).extension<AppColors>() ?? AppColors.light;
}

/// Soft card elevation from the design system (`shadow-card`, `shadow-raised`).
class AppShadows {
  const AppShadows._();

  static const card = [
    BoxShadow(color: Color(0x0D101828), blurRadius: 2, offset: Offset(0, 1)),
  ];

  static const raised = [
    BoxShadow(color: Color(0x1A101828), blurRadius: 24, offset: Offset(0, 8)),
  ];
}
