import 'package:attendance_app/core/error/app_exception.dart';
import 'package:attendance_app/data/datasources/onboarding_service.dart';
import 'package:attendance_app/domain/repositories/onboarding_repository.dart';

class OnboardingRepositoryImpl implements OnboardingRepository {
  OnboardingRepositoryImpl(this._service);

  final OnboardingService _service;

  @override
  Future<void> registerCompany({
    required String companyName,
    required String adminName,
    required Map<String, dynamic> location,
    required String shiftStart,
    required String shiftEnd,
    String? teamSize,
  }) => _guard(
    () => _service.registerCompany({
      'companyName': companyName.trim(),
      'adminName': adminName.trim(),
      'location': location,
      'shiftStart': shiftStart,
      'shiftEnd': shiftEnd,
      'teamSize': ?teamSize,
    }),
  );

  @override
  Future<String> claimJoin({String? code, String? name}) async {
    final result = await _guard(
      () => _service.claimJoin(
        code: code?.trim().toUpperCase(),
        name: name?.trim(),
      ),
    );
    return result['status'] as String? ?? 'active';
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

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } catch (error) {
      throw ErrorMapper.map(error);
    }
  }
}
