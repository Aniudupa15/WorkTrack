import 'package:attendance_app/core/error/app_exception.dart';
import 'package:attendance_app/domain/repositories/leave_repository.dart';
import 'package:attendance_app/data/models/leave_model.dart';
import 'package:attendance_app/data/datasources/database_service.dart';

class LeaveRepositoryImpl implements LeaveRepository {
  LeaveRepositoryImpl(this._db);

  final DatabaseService _db;

  @override
  Future<String> submitLeave(String companyId, LeaveModel leave) async {
    try {
      return await _db.submitLeave(companyId, leave);
    } catch (error) {
      throw ErrorMapper.map(error);
    }
  }

  @override
  Future<void> updateLeaveStatus(
    String companyId,
    String leaveId,
    String status,
    String? adminNote,
  ) async {
    try {
      await _db.updateLeaveStatus(companyId, leaveId, status, adminNote);
    } catch (error) {
      throw ErrorMapper.map(error);
    }
  }

  @override
  Stream<List<LeaveModel>> watchAllLeaves(String companyId) =>
      _db.getAllLeaves(companyId);

  @override
  Stream<List<LeaveModel>> watchEmployeeLeaves(
    String companyId,
    String employeeId,
  ) => _db.getEmployeeLeaves(companyId, employeeId);

  @override
  Stream<List<LeaveModel>> watchPendingLeaves(String companyId) =>
      _db.getPendingLeaves(companyId);
}
