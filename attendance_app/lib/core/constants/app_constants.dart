/// Application-wide constants and default values.
///
/// Anything that was previously a "magic number" or repeated literal in the UI
/// or data layer lives here so behaviour is tuned in one place.
class AppConstants {
  const AppConstants._();

  /// Reverse-DNS application identifier (used as the map tile user-agent and,
  /// eventually, the Android/iOS bundle id).
  static const String packageName = 'com.punchin.app';

  /// OpenStreetMap raster tile endpoint — no API key required.
  static const String osmTileUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  // ── Geofence / attendance defaults ─────────────────────────────────────────
  static const double defaultGeofenceRadiusMeters = 100.0;
  static const double minGeofenceRadiusMeters = 10.0;
  static const double maxGeofenceRadiusMeters = 5000.0;

  /// Minutes past shift start after which a check-in is flagged late. Mirrors
  /// the server-side grace period in `cloud_functions/index.js`.
  static const int lateGracePeriodMinutes = 15;

  static const String defaultShiftStart = '09:00';
  static const String defaultShiftEnd = '18:00';

  // ── Query limits ────────────────────────────────────────────────────────────
  static const int attendanceHistoryLimit = 60;
  static const int attendanceLogsLimit = 200;
}
