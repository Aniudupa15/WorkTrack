import 'dart:io';

import 'package:attendance_app/data/models/attendance_model.dart';

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
    required Map<String, dynamic> location,
    String? selfieStoragePath,
  });

  Future<CheckOutcome> checkOut({
    required String companyId,
    required String employeeId,
    required Map<String, dynamic> location,
  });

  Future<String> uploadSelfie(String companyId, String uid, File file);

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

  Stream<List<AttendanceModel>> watchAllLogs(
    String companyId, {
    String? dateFilter,
  });

  Future<List<AttendanceModel>> getAttendanceForMonth(
    String companyId,
    String yearMonth,
  );
}
