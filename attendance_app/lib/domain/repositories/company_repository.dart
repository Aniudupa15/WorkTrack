import 'package:attendance_app/data/models/company_model.dart';

/// Company profile and settings.
abstract interface class CompanyRepository {
  Future<CompanyModel?> getCompany(String companyId);

  Future<void> updateSettings(String companyId, Map<String, dynamic> settings);
}
