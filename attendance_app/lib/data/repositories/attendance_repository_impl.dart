import 'dart:io';

import 'package:attendance_app/core/error/app_exception.dart';
import 'package:attendance_app/domain/repositories/attendance_repository.dart';
import 'package:attendance_app/data/models/attendance_model.dart';
import 'package:attendance_app/data/datasources/attendance_service.dart';
import 'package:attendance_app/data/datasources/database_service.dart';
import 'package:attendance_app/data/datasources/storage_service.dart';

class AttendanceRepositoryImpl implements AttendanceRepository {
  AttendanceRepositoryImpl(this._attendance, this._db, this._storage);

  final AttendanceService _attendance;
  final DatabaseService _db;
  final StorageService _storage;

  @override
  Future<String> checkIn({
    required String companyId,
    required Map<String, dynamic> location,
    String? selfieStoragePath,
  }) async {
    try {
      return await _attendance.checkIn(
        companyId: companyId,
        location: location,
        selfieStoragePath: selfieStoragePath,
      );
    } catch (error) {
      throw ErrorMapper.map(error);
    }
  }

  @override
  Future<String> checkOut({
    required String companyId,
    required Map<String, dynamic> location,
  }) async {
    try {
      return await _attendance.checkOut(
        companyId: companyId,
        location: location,
      );
    } catch (error) {
      throw ErrorMapper.map(error);
    }
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
