import 'dart:typed_data';

import 'package:firebase_core/firebase_core.dart';

import 'package:attendance_app/core/error/app_exception.dart';
import 'package:attendance_app/data/datasources/connectivity_service.dart';
import 'package:attendance_app/data/datasources/database_service.dart';
import 'package:attendance_app/data/datasources/storage_service.dart';
import 'package:attendance_app/data/models/attendance_model.dart';
import 'package:attendance_app/data/models/location_model.dart';
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
    LocationModel? site,
    String? selfieStoragePath,
  }) {
    return _write(
      () => _db.performCheckIn(
        companyId: companyId,
        employeeId: employeeId,
        employeeName: employeeName,
        shiftStart: shiftStart,
        location: location,
        site: site,
        selfieStoragePath: selfieStoragePath,
      ),
    );
  }

  @override
  Future<CheckOutcome> checkOut({
    required String companyId,
    required String employeeId,
    required Map<String, dynamic> location,
    LocationModel? site,
  }) {
    return _write(
      () => _db.performCheckOut(
        companyId: companyId,
        employeeId: employeeId,
        location: location,
        site: site,
      ),
    );
  }

  /// Fires a Firestore write and awaits the server ack.
  ///
  /// Punches are refused while offline: Security Rules judge the punch by the
  /// server clock at the moment the write reaches Firestore, so a write queued
  /// in the local cache would be stamped with the reconnect time — or rejected
  /// on sync and silently lost.
  Future<CheckOutcome> _write(Future<void> Function() write) async {
    if (await _connectivity.isOffline()) {
      throw const AppException(
        'You’re offline. Connect to the internet to punch — punch times are '
        'verified by the server.',
        code: 'offline',
      );
    }
    try {
      await write();
      return CheckOutcome.synced;
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') {
        throw AppException(
          'The server rejected this punch. Make sure you are inside your work '
          'zone, within your shift, and your phone’s date and time are set '
          'automatically.',
          code: error.code,
        );
      }
      throw ErrorMapper.map(error);
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
  Future<String> uploadSelfie(
    String companyId,
    String uid,
    Uint8List bytes,
  ) async {
    try {
      return await _storage.uploadSelfie(companyId, uid, bytes);
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
    String? since,
  }) =>
      _db.getAllAttendanceLogs(companyId, dateFilter: dateFilter, since: since);

  @override
  Future<List<AttendanceModel>> getAttendanceForMonth(
    String companyId,
    String yearMonth, {
    String? since,
  }) async {
    try {
      return await _db.getAttendanceForMonth(
        companyId,
        yearMonth,
        since: since,
      );
    } catch (error) {
      throw ErrorMapper.map(error);
    }
  }
}
