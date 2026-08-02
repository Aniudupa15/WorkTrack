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

  /// Replays a batch of offline-captured events. Returns one result map per
  /// event: `{ clientId, status: created|updated|duplicate|error, code?, message? }`.
  Future<List<Map<String, dynamic>>> syncOfflineAttendance({
    required String companyId,
    required List<Map<String, dynamic>> events,
  }) async {
    final result = await _functions.httpsCallable('syncOfflineAttendance').call(
      {'companyId': companyId, 'events': events},
    );
    final data = result.data as Map<Object?, Object?>;
    final results = (data['results'] as List<Object?>? ?? const []);
    return results
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList(growable: false);
  }
}
