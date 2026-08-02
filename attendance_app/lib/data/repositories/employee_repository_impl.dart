import 'package:attendance_app/core/error/app_exception.dart';
import 'package:attendance_app/domain/repositories/employee_repository.dart';
import 'package:attendance_app/data/models/user_model.dart';
import 'package:attendance_app/data/datasources/auth_service.dart';
import 'package:attendance_app/data/datasources/database_service.dart';

class EmployeeRepositoryImpl implements EmployeeRepository {
  EmployeeRepositoryImpl(this._auth, this._db);

  final AuthService _auth;
  final DatabaseService _db;

  @override
  Future<String> addEmployee({
    required String companyId,
    required String name,
    required String email,
    String? phone,
    String? department,
    String? position,
    Map<String, dynamic>? workLocation,
    required Map<String, String> shift,
  }) async {
    try {
      return await _auth.addEmployee(
        companyId: companyId,
        name: name,
        email: email,
        phone: phone,
        department: department,
        position: position,
        workLocation: workLocation,
        shift: shift,
      );
    } catch (error) {
      throw ErrorMapper.map(error);
    }
  }

  @override
  Future<void> updateEmployee({
    required String companyId,
    required String employeeId,
    required String name,
    String? phone,
    String? department,
    String? position,
    Map<String, dynamic>? workLocation,
    required Map<String, String> shift,
  }) async {
    try {
      await _auth.updateEmployee(
        companyId: companyId,
        employeeId: employeeId,
        name: name,
        phone: phone,
        department: department,
        position: position,
        workLocation: workLocation,
        shift: shift,
      );
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
  Future<void> saveFcmToken(
    String companyId,
    String employeeId,
    String token,
  ) => _db.saveEmployeeFcmToken(companyId, employeeId, token);
}
