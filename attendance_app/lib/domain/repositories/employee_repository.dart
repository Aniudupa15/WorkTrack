import 'package:attendance_app/data/models/user_model.dart';

/// Employee directory and admin-side profile management.
///
/// Employees self-join via a company code (see AuthRepository.signUpWithCode);
/// the admin then edits their profile — shift, status — with the methods below
/// (work sites are assigned through LocationRepository). All reads stream from Firestore under the company subcollection.
abstract interface class EmployeeRepository {
  Future<void> updateEmployee({
    required String companyId,
    required String employeeId,
    required String name,
    String? phone,
    String? department,
    String? position,
    required Map<String, String> shift,
  });

  Future<void> deleteEmployee(String companyId, String employeeId);

  Stream<List<UserModel>> watchEmployees(String companyId);

  Future<List<UserModel>> getEmployeesOnce(String companyId);

  Stream<List<UserModel>> watchPendingEmployees(String companyId);

  /// Approves (`active`) or declines (`inactive`) a pending joiner.
  Future<void> setStatus(String companyId, String employeeId, String status);

  /// Unclaimed phone invites: maps with name, phone, department, ….
  Stream<List<Map<String, dynamic>>> watchInvites(String companyId);

  Future<void> deleteInvite(String phone);

  Future<void> saveFcmToken(String companyId, String employeeId, String token);
}
