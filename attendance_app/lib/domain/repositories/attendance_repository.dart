import 'dart:io';

import 'package:attendance_app/data/models/attendance_model.dart';

/// Attendance capture and history.
///
/// Check-in/out are server-authoritative (validated by Cloud Functions); the
/// device never writes attendance documents directly.
abstract interface class AttendanceRepository {
  Future<String> checkIn({
    required String companyId,
    required Map<String, dynamic> location,
    String? selfieStoragePath,
  });

  Future<String> checkOut({
    required String companyId,
    required Map<String, dynamic> location,
  });

  Future<String> uploadSelfie(String companyId, String uid, File file);

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
