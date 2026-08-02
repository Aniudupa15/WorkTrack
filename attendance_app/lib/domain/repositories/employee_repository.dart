import 'package:attendance_app/data/models/user_model.dart';

/// Employee lifecycle (admin-owned) and directory queries.
///
/// Account provisioning (create/update) is delegated to server Cloud Functions;
/// reads stream directly from Firestore under the company subcollection.
abstract interface class EmployeeRepository {
  Future<String> addEmployee({
    required String companyId,
    required String name,
    required String email,
    String? phone,
    String? department,
    String? position,
    Map<String, dynamic>? workLocation,
    required Map<String, String> shift,
  });

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
