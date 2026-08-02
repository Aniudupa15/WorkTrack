import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:uuid/uuid.dart';

import 'package:attendance_app/core/error/app_exception.dart';
import 'package:attendance_app/core/utils/logger.dart';
import 'package:attendance_app/data/datasources/attendance_service.dart';
import 'package:attendance_app/data/datasources/connectivity_service.dart';
import 'package:attendance_app/data/datasources/database_service.dart';
import 'package:attendance_app/data/datasources/offline_attendance_store.dart';
import 'package:attendance_app/data/datasources/storage_service.dart';
import 'package:attendance_app/data/models/attendance_model.dart';
import 'package:attendance_app/domain/repositories/attendance_repository.dart';

class AttendanceRepositoryImpl implements AttendanceRepository {
  AttendanceRepositoryImpl(
    this._attendance,
    this._db,
    this._storage,
    this._store,
    this._connectivity,
  );

  final AttendanceService _attendance;
  final DatabaseService _db;
  final StorageService _storage;
  final OfflineAttendanceStore _store;
  final ConnectivityService _connectivity;
  static const _uuid = Uuid();

  /// Function error codes that indicate a transient/network failure — for these
  /// we fall back to the offline queue instead of surfacing an error.
  static const _networkCodes = {'unavailable', 'deadline-exceeded'};

  /// Function error codes that will never succeed on retry — drop from queue.
  static const _permanentCodes = {
    'invalid-argument',
    'permission-denied',
    'failed-precondition',
    'already-exists',
    'not-found',
    'unauthenticated',
  };

  @override
  Future<CheckOutcome> checkIn({
    required String companyId,
    required Map<String, dynamic> location,
    String? selfieStoragePath,
  }) {
    return _capture(
      companyId: companyId,
      type: 'checkIn',
      location: location,
      online: () => _attendance.checkIn(
        companyId: companyId,
        location: location,
        selfieStoragePath: selfieStoragePath,
      ),
    );
  }

  @override
  Future<CheckOutcome> checkOut({
    required String companyId,
    required Map<String, dynamic> location,
  }) {
    return _capture(
      companyId: companyId,
      type: 'checkOut',
      location: location,
      online: () =>
          _attendance.checkOut(companyId: companyId, location: location),
    );
  }

  /// Shared check-in/out flow: try the server when online, otherwise (or on a
  /// transient network failure) queue the event locally for later sync.
  Future<CheckOutcome> _capture({
    required String companyId,
    required String type,
    required Map<String, dynamic> location,
    required Future<String> Function() online,
  }) async {
    if (await _connectivity.isOffline()) {
      await _enqueue(companyId, type, location);
      return CheckOutcome.queuedOffline;
    }
    try {
      await online();
      return CheckOutcome.synced;
    } on FirebaseFunctionsException catch (error) {
      if (_networkCodes.contains(error.code)) {
        await _enqueue(companyId, type, location);
        return CheckOutcome.queuedOffline;
      }
      throw ErrorMapper.map(error);
    } catch (error) {
      throw ErrorMapper.map(error);
    }
  }

  Future<void> _enqueue(
    String companyId,
    String type,
    Map<String, dynamic> location,
  ) async {
    await _store.add({
      'clientId': _uuid.v4(),
      'companyId': companyId,
      'type': type,
      'location': location,
      'capturedAt': DateTime.now().millisecondsSinceEpoch,
    });
    AppLogger.info(
      'Attendance $type queued offline (${_store.length} pending)',
    );
  }

  @override
  int get pendingSyncCount => _store.length;

  @override
  Future<int> syncPending(String companyId) async {
    final batch = _store
        .all()
        .where((e) => e['companyId'] == companyId)
        .toList(growable: false);
    if (batch.isEmpty) return 0;

    final List<Map<String, dynamic>> results;
    try {
      results = await _attendance.syncOfflineAttendance(
        companyId: companyId,
        events: batch
            .map(
              (e) => {
                'clientId': e['clientId'],
                'type': e['type'],
                'location': e['location'],
                'capturedAt': e['capturedAt'],
              },
            )
            .toList(growable: false),
      );
    } catch (error) {
      // Transient — keep the queue and try again on the next reconnect.
      AppLogger.warn('Offline sync attempt failed: $error');
      return 0;
    }

    var synced = 0;
    for (final result in results) {
      final clientId = result['clientId'] as String?;
      final status = result['status'] as String?;
      if (clientId == null) continue;
      if (status == 'created' || status == 'updated') {
        await _store.remove(clientId);
        synced++;
      } else if (status == 'duplicate') {
        await _store.remove(clientId);
      } else if (status == 'error' &&
          _permanentCodes.contains(result['code'])) {
        AppLogger.warn(
          'Dropping unsyncable event $clientId: ${result['message']}',
        );
        await _store.remove(clientId);
      }
    }
    if (synced > 0) AppLogger.info('Synced $synced offline attendance events');
    return synced;
  }

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
