/// Spacing scale (4-pt grid) and corner-radius tokens.
///
/// Using named steps instead of ad-hoc numbers keeps rhythm consistent across
/// every screen.
class AppSpacing {
  const AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
}

/// Corner-radius tokens (design system v2): soft corners — 12 for controls,
/// 16 for cards, 24 for sheets, fully round for pills and avatars.
class AppRadius {
  const AppRadius._();

  /// Small chips, tags, calendar days.
  static const double sm = 8;

  /// Buttons, inputs, list tiles.
  static const double md = 12;

  /// Cards.
  static const double lg = 16;

  static const double xl = 20;

  /// Bottom sheets and dialogs.
  static const double xxl = 24;

  static const double pill = 999;
}
