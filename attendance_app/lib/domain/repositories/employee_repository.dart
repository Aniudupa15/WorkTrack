import 'package:attendance_app/data/models/user_model.dart';

/// Employee directory and admin-side profile management.
///
/// Employees self-join via a company code (see AuthRepository.signUpWithCode);
/// the admin then edits their profile — work location, shift, status — with the
/// methods below. All reads stream from Firestore under the company subcollection.
abstract interface class EmployeeRepository {
  Future<void> updateEmployee({
    required String companyId,
    required String employeeId,
    required String name,
    String? phone,
    String? department,
    String? position,
    Map<String, dynamic>? workLocation,
    required Map<String, String> shift,
  });

  Future<void> deleteEmployee(String companyId, String employeeId);

  Stream<List<UserModel>> watchEmployees(String companyId);

  Future<List<UserModel>> getEmployeesOnce(String companyId);

  Future<void> saveFcmToken(String companyId, String employeeId, String token);
}
