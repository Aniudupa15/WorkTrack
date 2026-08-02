import 'package:attendance_app/data/models/leave_model.dart';

/// Leave requests and approvals.
abstract interface class LeaveRepository {
  Future<String> submitLeave(String companyId, LeaveModel leave);

  Future<void> updateLeaveStatus(
    String companyId,
    String leaveId,
    String status,
    String? adminNote,
  );

  Stream<List<LeaveModel>> watchAllLeaves(String companyId);

  Stream<List<LeaveModel>> watchEmployeeLeaves(
    String companyId,
    String employeeId,
  );

  Stream<List<LeaveModel>> watchPendingLeaves(String companyId);
}
