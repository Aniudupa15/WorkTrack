import 'package:cloud_functions/cloud_functions.dart';

import 'package:attendance_app/core/config/backend.dart';

/// Calls the onboarding Cloud Functions. Companies, joins and invites are
/// created only server-side; Security Rules give clients no way to write them.
class OnboardingService {
  OnboardingService({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'asia-south1');

  final FirebaseFunctions _functions;

  Future<Map<String, dynamic>> _call(
    String name,
    Map<String, dynamic> data,
  ) async {
    final result = await backendCallable(_functions, name).call(data);
    return Map<String, dynamic>.from(result.data as Map);
  }

  Future<Map<String, dynamic>> registerCompany(Map<String, dynamic> data) =>
      _call('registerCompany', data);

  Future<Map<String, dynamic>> claimJoin({
    String? code,
    String? name,
    String? email,
    String? employeeNumber,
  }) => _call('claimJoin', {
    'code': ?code,
    'name': ?name,
    'email': ?email,
    'employeeNumber': ?employeeNumber,
  });

  Future<Map<String, dynamic>> importEmployees(
    String companyId,
    List<Map<String, dynamic>> rows,
  ) => _call('importEmployees', {'companyId': companyId, 'rows': rows});

  Future<void> deleteMyAccount() => _call('deleteMyAccount', {});

  Future<String> resetJoinCode(String companyId) async =>
      (await _call('resetJoinCode', {'companyId': companyId}))['employeeCode']
          as String;
}
