import 'package:attendance_app/core/error/app_exception.dart';
import 'package:attendance_app/data/datasources/onboarding_service.dart';
import 'package:attendance_app/domain/repositories/onboarding_repository.dart';

class OnboardingRepositoryImpl implements OnboardingRepository {
  OnboardingRepositoryImpl(this._service);

  final OnboardingService _service;

  @override
  Future<String> registerCompany({
    required String companyName,
    required String adminName,
    required List<Map<String, dynamic>> locations,
    required String shiftStart,
    required String shiftEnd,
    String? teamSize,
    String? industry,
    String? gstin,
    List<int> workingDays = const [1, 2, 3, 4, 5, 6],
    int lateAfterMinutes = 15,
    bool checkoutInZone = true,
    bool shiftReminders = true,
    bool selfieRequired = false,
  }) async {
    final r = await _guard(
      () => _service.registerCompany({
        'companyName': companyName.trim(),
        'adminName': adminName.trim(),
        'locations': locations,
        'shiftStart': shiftStart,
        'shiftEnd': shiftEnd,
        'teamSize': ?teamSize,
        'industry': ?industry,
        'gstin': ?gstin,
        'workingDays': workingDays,
        'lateAfterMinutes': lateAfterMinutes,
        'checkoutInZone': checkoutInZone,
        'shiftReminders': shiftReminders,
        'selfieRequired': selfieRequired,
      }),
    );
    return r['companyId'] as String;
  }

  @override
  Future<({String companyId, String status})> claimJoin({
    String? code,
    String? name,
    String? email,
    String? employeeNumber,
  }) async {
    final result = await _guard(
      () => _service.claimJoin(
        code: code?.trim().toUpperCase().replaceAll('-', ''),
        name: name?.trim(),
        email: email?.trim(),
        employeeNumber: employeeNumber?.trim(),
      ),
    );
    return (
      companyId: result['companyId'] as String? ?? '',
      status: result['status'] as String? ?? 'active',
    );
  }

  @override
  Future<ImportResult> importEmployees(
    String companyId,
    List<Map<String, dynamic>> rows,
  ) async {
    final result = await _guard(
      () => _service.importEmployees(companyId, rows),
    );
    return ImportResult(
      created: (result['created'] as num?)?.toInt() ?? 0,
      updated: (result['updated'] as num?)?.toInt() ?? 0,
      errors: {
        for (final e in (result['errors'] as List? ?? const []))
          ((e as Map)['row'] as num).toInt(): e['message'] as String,
      },
    );
  }

  @override
  Future<String> resetJoinCode(String companyId) =>
      _guard(() => _service.resetJoinCode(companyId));

  @override
  Future<void> deleteMyAccount() => _guard(_service.deleteMyAccount);

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } catch (error) {
      throw ErrorMapper.map(error);
    }
  }
}
