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

  @override
  Future<({String adminCode, String employeeCode})> createCompany({
    required String superAdminUid,
    required String companyName,
    String? address,
    required String adminName,
    required String adminEmail,
    required String shiftStart,
    required String shiftEnd,
  }) async {
    try {
      return await _db.createCompany(
        superAdminUid: superAdminUid,
        companyName: companyName,
        address: address,
        adminName: adminName,
        adminEmail: adminEmail,
        shiftStart: shiftStart,
        shiftEnd: shiftEnd,
      );
    } catch (error) {
      throw ErrorMapper.map(error);
    }
  }

  @override
  Stream<List<CompanyModel>> watchCompanies() => _db.watchCompanies();

  @override
  Future<void> setStatus(String companyId, String status) async {
    try {
      await _db.setCompanyStatus(companyId, status);
    } catch (error) {
      throw ErrorMapper.map(error);
    }
  }

  @override
  Future<({String? code, bool used})> getAdminCode(String companyId) async {
    try {
      return await _db.getAdminCode(companyId);
    } catch (error) {
      throw ErrorMapper.map(error);
    }
  }
}
