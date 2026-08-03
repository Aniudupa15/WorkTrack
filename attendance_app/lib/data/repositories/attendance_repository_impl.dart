import 'dart:async';
import 'dart:io';

import 'package:attendance_app/core/error/app_exception.dart';
import 'package:attendance_app/data/datasources/connectivity_service.dart';
import 'package:attendance_app/data/datasources/database_service.dart';
import 'package:attendance_app/data/datasources/storage_service.dart';
import 'package:attendance_app/data/models/attendance_model.dart';
import 'package:attendance_app/domain/repositories/attendance_repository.dart';

class AttendanceRepositoryImpl implements AttendanceRepository {
  AttendanceRepositoryImpl(this._db, this._storage, this._connectivity);

  final DatabaseService _db;
  final StorageService _storage;
  final ConnectivityService _connectivity;

  @override
  Future<CheckOutcome> checkIn({
    required String companyId,
    required String employeeId,
    required String employeeName,
    required String shiftStart,
    required Map<String, dynamic> location,
    String? selfieStoragePath,
  }) {
    return _write(
      () => _db.performCheckIn(
        companyId: companyId,
        employeeId: employeeId,
        employeeName: employeeName,
        shiftStart: shiftStart,
        location: location,
        selfieStoragePath: selfieStoragePath,
      ),
    );
  }

  @override
  Future<CheckOutcome> checkOut({
    required String companyId,
    required String employeeId,
    required Map<String, dynamic> location,
  }) {
    return _write(
      () => _db.performCheckOut(
        companyId: companyId,
        employeeId: employeeId,
        location: location,
      ),
    );
  }

  /// Fires a Firestore write. Online, we await the server ack and report
  /// [CheckOutcome.synced]. Offline, the write lands in Firestore's local cache
  /// (its Future stays pending until reconnect, when it syncs on its own), so we
  /// don't await it and report [CheckOutcome.queuedOffline].
  Future<CheckOutcome> _write(Future<void> Function() write) async {
    try {
      final offline = await _connectivity.isOffline();
      final pending = write();
      if (offline) {
        unawaited(pending.catchError((_) {}));
        return CheckOutcome.queuedOffline;
      }
      await pending;
      return CheckOutcome.synced;
    } catch (error) {
      throw ErrorMapper.map(error);
    }
  }

  // Offline persistence is handled by Firestore itself, so there is no separate
  // queue to drain.
  @override
  int get pendingSyncCount => 0;

  @override
  Future<int> syncPending(String companyId) async => 0;

  @override
  Future<String> uploadSelfie(String companyId, String uid, File file) async {
    try {
      return await _storage.uploadSelfie(companyId, uid, file);
    } catch (error) {
      throw ErrorMapper.map(error);
    }
  }

  @override
  Future<AttendanceModel?> getTodayAttendance(
    String companyId,
    String employeeId,
  ) async {
    try {
      return await _db.getTodayAttendance(companyId, employeeId);
    } catch (error) {
      throw ErrorMapper.map(error);
    }
  }

  @override
  Stream<List<AttendanceModel>> watchEmployeeHistory(
    String companyId,
    String employeeId,
  ) => _db.getEmployeeAttendanceHistory(companyId, employeeId);

  @override
  Stream<List<AttendanceModel>> watchAllLogs(
    String companyId, {
    String? dateFilter,
  }) => _db.getAllAttendanceLogs(companyId, dateFilter: dateFilter);

  @override
  Future<List<AttendanceModel>> getAttendanceForMonth(
    String companyId,
    String yearMonth,
  ) async {
    try {
      return await _db.getAttendanceForMonth(companyId, yearMonth);
    } catch (error) {
      throw ErrorMapper.map(error);
    }
  }
}
