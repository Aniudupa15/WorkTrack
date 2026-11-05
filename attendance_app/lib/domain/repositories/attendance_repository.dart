import 'dart:typed_data';

import 'package:attendance_app/data/models/attendance_model.dart';
import 'package:attendance_app/data/models/location_model.dart';
import 'package:attendance_app/data/models/punch_attempt_model.dart';

/// Outcome of a check-in/out attempt.
enum CheckOutcome {
  /// Validated and written by the server immediately.
  synced,

  /// Device was offline; captured locally and queued for later sync.
  queuedOffline,
}

/// Attendance capture and history.
///
/// Geofence is validated on the device, then the record is written directly to
/// Firestore (Security Rules restrict an employee to their own records). Writes
/// made while offline are held in Firestore's local cache and sync
/// automatically on reconnect.
abstract interface class AttendanceRepository {
  Future<CheckOutcome> checkIn({
    required String companyId,
    required String employeeId,
    required String employeeName,
    required String shiftStart,
    int lateAfterMinutes,
    required Map<String, dynamic> location,
    LocationModel? site,
    String? selfieStoragePath,
  });

  Future<CheckOutcome> checkOut({
    required String companyId,
    required String employeeId,
    required Map<String, dynamic> location,
    LocationModel? site,
  });

  /// Records a punch refused for being outside every zone (best effort).
  Future<void> logFailedAttempt({
    required String companyId,
    required String employeeId,
    required String employeeName,
    LocationModel? nearest,
    required double distance,
    double? accuracy,
  });

  /// Failed attempts on [date] ('yyyy-MM-dd'), for the admin.
  Stream<List<PunchAttempt>> watchFailedAttempts(String companyId, String date);

  Future<String> uploadSelfie(String companyId, String uid, Uint8List bytes);

  /// Number of events waiting to sync.
  int get pendingSyncCount;

  /// Replays queued offline events for [companyId]. Returns how many synced.
  Future<int> syncPending(String companyId);

  Future<AttendanceModel?> getTodayAttendance(
    String companyId,
    String employeeId,
  );

  Stream<List<AttendanceModel>> watchEmployeeHistory(
    String companyId,
    String employeeId,
  );

  /// [since] limits a Free company's admin to recent history.
  Stream<List<AttendanceModel>> watchAllLogs(
    String companyId, {
    String? dateFilter,
    String? since,
  });

  Future<List<AttendanceModel>> getAttendanceForMonth(
    String companyId,
    String yearMonth, {
    String? since,
  });
}
