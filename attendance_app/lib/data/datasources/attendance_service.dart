import 'package:cloud_functions/cloud_functions.dart';

/// Attendance is server-authoritative: timestamps, dates, geofence validation,
/// duplicate protection, and late status are never trusted from the device.
class AttendanceService {
  final FirebaseFunctions _functions;
  AttendanceService({FirebaseFunctions? functions})
    : _functions = functions ?? FirebaseFunctions.instance;

  Future<String> checkIn({
    required String companyId,
    required Map<String, dynamic> location,
    String? selfieStoragePath,
  }) async {
    final result = await _functions.httpsCallable('onCheckIn').call({
      'companyId': companyId,
      'location': location,
      'selfieStoragePath': selfieStoragePath,
    });
    return (result.data as Map<Object?, Object?>)['attendanceId']! as String;
  }

  Future<String> checkOut({
    required String companyId,
    required Map<String, dynamic> location,
  }) async {
    final result = await _functions.httpsCallable('onCheckOut').call({
      'companyId': companyId,
      'location': location,
    });
    return (result.data as Map<Object?, Object?>)['attendanceId']! as String;
  }
}
