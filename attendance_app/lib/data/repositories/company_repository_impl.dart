import 'package:attendance_app/core/error/app_exception.dart';
import 'package:attendance_app/domain/repositories/company_repository.dart';
import 'package:attendance_app/data/models/company_model.dart';
import 'package:attendance_app/data/datasources/database_service.dart';

class CompanyRepositoryImpl implements CompanyRepository {
  CompanyRepositoryImpl(this._db);

  final DatabaseService _db;

  @override
  Future<CompanyModel?> getCompany(String companyId) async {
    try {
      return await _db.getCompany(companyId);
    } catch (error) {
      throw ErrorMapper.map(error);
    }
  }

  @override
  Future<void> updateSettings(
    String companyId,
    Map<String, dynamic> settings,
  ) async {
    try {
      await _db.updateCompanySettings(companyId, settings);
    } catch (error) {
      throw ErrorMapper.map(error);
    }
  }
}
