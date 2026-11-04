import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:attendance_app/core/error/app_exception.dart';
import 'package:attendance_app/data/datasources/database_service.dart';
import 'package:attendance_app/data/models/user_model.dart';
import 'package:attendance_app/domain/repositories/employee_repository.dart';

class EmployeeRepositoryImpl implements EmployeeRepository {
  EmployeeRepositoryImpl(this._db);

  final DatabaseService _db;

  @override
  Future<void> updateEmployee({
    required String companyId,
    required String employeeId,
    required String name,
    String? phone,
    String? department,
    String? position,
    required Map<String, String> shift,
  }) async {
    try {
      await _db.updateEmployee(companyId, employeeId, {
        'name': name.trim(),
        'phone': phone,
        'department': department,
        'position': position,
        'shift': shift,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (error) {
      throw ErrorMapper.map(error);
    }
  }

  @override
  Future<void> deleteEmployee(String companyId, String employeeId) async {
    try {
      await _db.deleteEmployee(companyId, employeeId);
    } catch (error) {
      throw ErrorMapper.map(error);
    }
  }

  @override
  Stream<List<UserModel>> watchEmployees(String companyId) =>
      _db.getAllEmployees(companyId);

  @override
  Future<List<UserModel>> getEmployeesOnce(String companyId) async {
    try {
      return await _db.getAllEmployeesOnce(companyId);
    } catch (error) {
      throw ErrorMapper.map(error);
    }
  }

  @override
  Stream<List<UserModel>> watchPendingEmployees(String companyId) =>
      _db.watchPendingEmployees(companyId);

  @override
  Future<void> setStatus(
    String companyId,
    String employeeId,
    String status,
  ) async {
    try {
      await _db.setEmployeeStatus(companyId, employeeId, status);
    } catch (error) {
      throw ErrorMapper.map(error);
    }
  }

  @override
  Stream<List<Map<String, dynamic>>> watchInvites(String companyId) =>
      _db.watchInvites(companyId);

  @override
  Future<void> deleteInvite(String phone) async {
    try {
      await _db.deleteInvite(phone);
    } catch (error) {
      throw ErrorMapper.map(error);
    }
  }

  @override
  Future<void> saveFcmToken(
    String companyId,
    String employeeId,
    String token,
  ) => _db.saveEmployeeFcmToken(companyId, employeeId, token);
}
