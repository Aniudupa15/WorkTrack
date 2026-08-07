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

/// Corner-radius tokens. Editorial identity: crisp, near-square corners — a
/// small, restrained rounding rather than soft pills.
class AppRadius {
  const AppRadius._();

  static const double sm = 2;
  static const double md = 4;
  static const double lg = 6;
  static const double xl = 8;
  static const double xxl = 10;
  static const double pill = 999;
}
