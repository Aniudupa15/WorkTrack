import 'package:intl/intl.dart';

import 'package:attendance_app/core/constants/app_constants.dart';

/// The company's wall clock, independent of the device's time zone.
///
/// Attendance days (`YYYY-MM-DD`) and late status are judged by Firestore
/// Security Rules against the server clock in this fixed offset, so the app
/// must derive them the same way or its writes are rejected.
class AttendanceClock {
  const AttendanceClock._();

  /// Now, as a UTC [DateTime] whose fields read as company wall-clock time.
  static DateTime now() => DateTime.now().toUtc().add(
    const Duration(minutes: AppConstants.attendanceUtcOffsetMinutes),
  );

  /// Today's attendance date key, e.g. `2026-10-30`.
  static String today() => DateFormat('yyyy-MM-dd').format(now());

  static int minutesOfDay(DateTime t) => t.hour * 60 + t.minute;

  /// Parses `HH:mm` into minutes past midnight, or null if malformed.
  static int? parseMinutes(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return h * 60 + m;
  }
}
