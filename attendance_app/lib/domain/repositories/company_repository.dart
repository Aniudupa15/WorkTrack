import 'package:attendance_app/data/models/company_model.dart';

/// Company profile and settings.
abstract interface class CompanyRepository {
  Future<CompanyModel?> getCompany(String companyId);

  Future<void> updateSettings(String companyId, Map<String, dynamic> settings);

  /// Super admin: provision a company. Returns the admin + employee codes.
  Future<({String adminCode, String employeeCode})> createCompany({
    required String superAdminUid,
    required String companyName,
    String? address,
    required String adminName,
    required String adminEmail,
    required String shiftStart,
    required String shiftEnd,
  });

  /// Super admin: watch every company.
  Stream<List<CompanyModel>> watchCompanies();

  /// Super admin: activate / suspend a company.
  Future<void> setStatus(String companyId, String status);

  /// Super admin: fetch a company's admin code (to re-share) and whether it's
  /// already been claimed.
  Future<({String? code, bool used})> getAdminCode(String companyId);
}
