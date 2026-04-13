// ─────────────────────────────────────────────────────────────────────────────
//  lib/theme/app_colors.dart
//  PunchIn — Ink & Violet color scheme
//
//  Usage:
//    import 'package:punchin/theme/app_colors.dart';
//
//    Container(color: AppColors.primary)
//    Text('Hello', style: TextStyle(color: AppColors.textPrimary))
//    BoxDecoration(boxShadow: AppColors.shadowRaised)
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

sealed class AppColors {
  AppColors._();

  // ── Brand ──────────────────────────────────────────────────────────────────
  /// The single source-of-truth accent used for CTAs, active states & focus.
  static const Color brand = Color(0xFF7C3AED);

  // ── Background ─────────────────────────────────────────────────────────────
  /// Deep ink-black. Used for the dark top-panel / Scaffold on dark screens.
  static const Color bgDark    = Color(0xFF0E0A1F);

  /// Slightly lifted surface on the dark panel (cards, bottom-sheets on dark).
  static const Color bgSurface = Color(0xFF1A1433);

  /// Soft lavender-white. Main Scaffold background on light screens.
  static const Color bgLight   = Color(0xFFF5F3FF);

  /// Pure white. Form cards, input fill, social buttons.
  static const Color bgWhite   = Color(0xFFFFFFFF);

  // ── Primary / Accent ramp ──────────────────────────────────────────────────
  /// Darkest violet — hover/pressed state on primary button.
  static const Color primaryDark  = Color(0xFF4C1D95);

  /// Core primary — all main action buttons, active tab indicators.
  static const Color primary      = Color(0xFF6D28D9);

  /// Lighter accent — icon fills, focus ring highlights.
  static const Color primaryLight = Color(0xFF7C3AED);

  /// Soft tint — chip backgrounds, badge fills, input focus surface.
  static const Color primaryTint  = Color(0xFFEDE9FE);

  /// Pale shimmer — neumorphic light-face shadow on light surface.
  static const Color primaryGlow  = Color(0xFFC4B5FD);

  // ── Neutral ramp ───────────────────────────────────────────────────────────
  /// Deepest text — headings, primary labels.
  static const Color textPrimary   = Color(0xFF0E0A1F);

  /// Body text — paragraphs, field values.
  static const Color textSecondary = Color(0xFF3B3354);

  /// Placeholder / hint / muted labels.
  static const Color textMuted     = Color(0xFF8B80A8);

  /// Disabled text.
  static const Color textDisabled  = Color(0xFFB8B0D0);

  /// On-dark primary text — headings on the dark panel.
  static const Color textOnDark    = Color(0xFFFFFFFF);

  /// On-dark muted — subtitles / descriptions on the dark panel.
  static const Color textOnDarkMuted = Color(0x66FFFFFF); // white 40 %

  // ── Border ─────────────────────────────────────────────────────────────────
  /// Default input / card border.
  static const Color border        = Color(0xFFDDD6FE);

  /// Stronger border — hovered or active state.
  static const Color borderStrong  = Color(0xFF7C3AED);

  /// Border on dark panel surfaces.
  static const Color borderDark    = Color(0xFF2E2550);

  // ── Semantic ───────────────────────────────────────────────────────────────
  static const Color success        = Color(0xFF16A34A);
  static const Color successSurface = Color(0xFFDCFCE7);
  static const Color successText    = Color(0xFF14532D);

  static const Color warning        = Color(0xFFD97706);
  static const Color warningSurface = Color(0xFFFEF3C7);
  static const Color warningText    = Color(0xFF78350F);

  static const Color error          = Color(0xFFDC2626);
  static const Color errorSurface   = Color(0xFFFEE2E2);
  static const Color errorText      = Color(0xFF7F1D1D);

  static const Color info           = Color(0xFF0284C7);
  static const Color infoSurface    = Color(0xFFE0F2FE);
  static const Color infoText       = Color(0xFF0C4A6E);

  // ── Status pills (attendance-specific) ────────────────────────────────────
  /// "Present" green pill.
  static const Color statusPresent        = Color(0xFF16A34A);
  static const Color statusPresentSurface = Color(0xFFDCFCE7);

  /// "Absent" red pill.
  static const Color statusAbsent         = Color(0xFFDC2626);
  static const Color statusAbsentSurface  = Color(0xFFFEE2E2);

  /// "Late" amber pill.
  static const Color statusLate           = Color(0xFFD97706);
  static const Color statusLateSurface    = Color(0xFFFEF3C7);

  /// "On Leave" blue pill.
  static const Color statusLeave          = Color(0xFF0284C7);
  static const Color statusLeaveSurface   = Color(0xFFE0F2FE);

  /// "Half Day" violet pill.
  static const Color statusHalfDay        = Color(0xFF7C3AED);
  static const Color statusHalfDaySurface = Color(0xFFEDE9FE);

  // ── Neumorphic shadows ─────────────────────────────────────────────────────
  // Light surface (bgLight #F5F3FF)
  // Light face  → slightly lighter/cooler than surface  → #FFFFFF
  // Dark face   → slightly darker/warmer than surface   → #C4B5FD at 55 %

  /// Raised / elevated — use on bgLight surface.
  static List<BoxShadow> get shadowRaised => const [
    BoxShadow(
      color: Color(0xFFFFFFFF),
      blurRadius: 12,
      offset: Offset(-5, -5),
    ),
    BoxShadow(
      color: Color(0x8CC4B5FD), // primaryGlow @ 55 %
      blurRadius: 12,
      offset: Offset(5, 5),
    ),
  ];

  /// Pressed / inset — use on bgLight surface when button is tapped.
  static List<BoxShadow> get shadowInset => const [
    BoxShadow(
      color: Color(0xFFFFFFFF),
      blurRadius: 9,
      offset: Offset(-3, -3),
    ),
    BoxShadow(
      color: Color(0x8CC4B5FD),
      blurRadius: 9,
      offset: Offset(3, 3),
    ),
  ];

  // Dark surface (bgDark #0E0A1F)
  // Light face  → slightly lighter dark → #1A1433 (bgSurface)
  // Dark face   → deeper shadow        → #050310

  /// Raised on dark surface.
  static List<BoxShadow> get shadowDarkRaised => const [
    BoxShadow(
      color: Color(0xFF1A1433),
      blurRadius: 12,
      offset: Offset(-5, -5),
    ),
    BoxShadow(
      color: Color(0xFF050310),
      blurRadius: 12,
      offset: Offset(5, 5),
    ),
  ];

  /// Pressed / inset on dark surface.
  static List<BoxShadow> get shadowDarkInset => const [
    BoxShadow(
      color: Color(0xFF1A1433),
      blurRadius: 9,
      offset: Offset(-3, -3),
    ),
    BoxShadow(
      color: Color(0xFF050310),
      blurRadius: 9,
      offset: Offset(3, 3),
    ),
  ];

  // Primary (violet) surface — for gold/accent-coloured neumorphic buttons
  // Light face  → lighter violet tint  → #A78BFA
  // Dark face   → deeper violet        → #4C1D95 @ 60 %

  /// Raised on primary (violet) surface.
  static List<BoxShadow> get shadowPrimaryRaised => const [
    BoxShadow(
      color: Color(0x99A78BFA),
      blurRadius: 14,
      offset: Offset(-5, -5),
    ),
    BoxShadow(
      color: Color(0x994C1D95),
      blurRadius: 14,
      offset: Offset(5, 5),
    ),
  ];

  /// Pressed on primary (violet) surface.
  static List<BoxShadow> get shadowPrimaryInset => const [
    BoxShadow(
      color: Color(0x99A78BFA),
      blurRadius: 10,
      offset: Offset(-3, -3),
    ),
    BoxShadow(
      color: Color(0x994C1D95),
      blurRadius: 10,
      offset: Offset(3, 3),
    ),
  ];

  // ── Card shadow (standard elevation) ──────────────────────────────────────
  /// Soft ambient shadow for floating cards and bottom sheets.
  static List<BoxShadow> get shadowCard => const [
    BoxShadow(
      color: Color(0x1A7C3AED), // brand @ 10 %
      blurRadius: 32,
      offset: Offset(0, 10),
    ),
  ];

  // ── Decorative circle overlays ─────────────────────────────────────────────
  /// Top-right decorative blob color on dark panel.
  static Color get decoBlobPrimary   => primaryLight.withOpacity(0.12);

  /// Bottom-left decorative blob color on dark panel.
  static Color get decoBlobSecondary => primaryGlow.withOpacity(0.07);

  // ── Gradient helpers ───────────────────────────────────────────────────────
  /// Vertical gradient for the primary CTA button.
  static const LinearGradient gradientPrimary = LinearGradient(
    colors: [Color(0xFF7C3AED), Color(0xFF5B21B6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Subtle violet-tinted background gradient for light screens.
  static const LinearGradient gradientBgLight = LinearGradient(
    colors: [Color(0xFFF5F3FF), Color(0xFFEDE9FE)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // ── ThemeData helpers ──────────────────────────────────────────────────────

  /// Returns a [ColorScheme] for use in [ThemeData].
  static ColorScheme get lightColorScheme => ColorScheme(
    brightness: Brightness.light,
    primary:          primary,
    onPrimary:        textOnDark,
    primaryContainer: primaryTint,
    onPrimaryContainer: primaryDark,
    secondary:        primaryLight,
    onSecondary:      textOnDark,
    secondaryContainer: primaryTint,
    onSecondaryContainer: primaryDark,
    surface:          bgWhite,
    onSurface:        textPrimary,
    error:            error,
    onError:          textOnDark,
  );

  static ColorScheme get darkColorScheme => ColorScheme(
    brightness: Brightness.dark,
    primary:          primaryLight,
    onPrimary:        textOnDark,
    primaryContainer: bgSurface,
    onPrimaryContainer: primaryGlow,
    secondary:        primaryGlow,
    onSecondary:      primaryDark,
    secondaryContainer: bgSurface,
    onSecondaryContainer: primaryGlow,
    surface:          bgDark,
    onSurface:        textOnDark,
    error:            error,
    onError:          textOnDark,
  );

  /// Full [ThemeData] — light mode.
  static ThemeData get lightTheme => ThemeData(
    useMaterial3:  true,
    colorScheme:   lightColorScheme,
    scaffoldBackgroundColor: bgLight,
    fontFamily:    'Inter',
    inputDecorationTheme: InputDecorationTheme(
      filled:    true,
      fillColor: bgWhite,
      hintStyle: TextStyle(color: textMuted, fontSize: 14),
      contentPadding:
      const EdgeInsets.symmetric(vertical: 15, horizontal: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: border, width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: borderStrong, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: error, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: error, width: 1.6),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor:  primary,
        foregroundColor:  textOnDark,
        minimumSize:      const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        elevation: 0,
        textStyle: const TextStyle(
          fontSize:   15,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primary,
        side:            const BorderSide(color: border, width: 1.2),
        minimumSize:     const Size(double.infinity, 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: const TextStyle(
          fontSize:   14,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primary,
        textStyle: const TextStyle(
          fontSize:   13.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior:         SnackBarBehavior.floating,
      backgroundColor:  primary,
      contentTextStyle: const TextStyle(
        color:      Colors.white,
        fontSize:   13.5,
        fontWeight: FontWeight.w500,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color:     border,
      thickness: 1,
      space:     1,
    ),
    chipTheme: ChipThemeData(
      backgroundColor:  primaryTint,
      labelStyle:       const TextStyle(
        color:      primaryDark,
        fontSize:   12,
        fontWeight: FontWeight.w600,
      ),
      side:             BorderSide.none,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    ),
  );

  /// Full [ThemeData] — dark mode.
  static ThemeData get darkTheme => ThemeData(
    useMaterial3:  true,
    colorScheme:   darkColorScheme,
    scaffoldBackgroundColor: bgDark,
    fontFamily:    'Inter',
    inputDecorationTheme: InputDecorationTheme(
      filled:    true,
      fillColor: bgSurface,
      hintStyle: TextStyle(color: textMuted, fontSize: 14),
      contentPadding:
      const EdgeInsets.symmetric(vertical: 15, horizontal: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: borderDark, width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primaryLight, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: error, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: error, width: 1.6),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor:  primaryLight,
        foregroundColor:  textOnDark,
        minimumSize:      const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        elevation: 0,
        textStyle: const TextStyle(
          fontSize:   15,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior:         SnackBarBehavior.floating,
      backgroundColor:  bgSurface,
      contentTextStyle: const TextStyle(
        color:      Colors.white,
        fontSize:   13.5,
        fontWeight: FontWeight.w500,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color:     borderDark,
      thickness: 1,
      space:     1,
    ),
    chipTheme: ChipThemeData(
      backgroundColor:  bgSurface,
      labelStyle:       const TextStyle(
        color:      primaryGlow,
        fontSize:   12,
        fontWeight: FontWeight.w600,
      ),
      side:             BorderSide.none,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  StatusColor — convenience helper for attendance status chips
//
//  Usage:
//    final colors = StatusColor.of(AttendanceStatus.present);
//    Container(color: colors.surface, child: Text('Present', style: TextStyle(color: colors.text)))
// ─────────────────────────────────────────────────────────────────────────────

enum AttendanceStatus { present, absent, late, leave, halfDay }

class StatusColor {
  final Color fill;
  final Color surface;
  final Color text;

  const StatusColor._({
    required this.fill,
    required this.surface,
    required this.text,
  });

  static StatusColor of(AttendanceStatus status) {
    switch (status) {
      case AttendanceStatus.present:
        return const StatusColor._(
          fill:    AppColors.statusPresent,
          surface: AppColors.statusPresentSurface,
          text:    AppColors.successText,
        );
      case AttendanceStatus.absent:
        return const StatusColor._(
          fill:    AppColors.statusAbsent,
          surface: AppColors.statusAbsentSurface,
          text:    AppColors.errorText,
        );
      case AttendanceStatus.late:
        return const StatusColor._(
          fill:    AppColors.statusLate,
          surface: AppColors.statusLateSurface,
          text:    AppColors.warningText,
        );
      case AttendanceStatus.leave:
        return const StatusColor._(
          fill:    AppColors.statusLeave,
          surface: AppColors.statusLeaveSurface,
          text:    AppColors.infoText,
        );
      case AttendanceStatus.halfDay:
        return const StatusColor._(
          fill:    AppColors.statusHalfDay,
          surface: AppColors.statusHalfDaySurface,
          text:    AppColors.primaryDark,
        );
    }
  }
}