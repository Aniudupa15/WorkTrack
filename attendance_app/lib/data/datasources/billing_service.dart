import 'package:cloud_functions/cloud_functions.dart';

/// Calls the billing Cloud Functions. Plan, seats and status are written only
/// server-side (after Razorpay verifies the payment).
class BillingService {
  BillingService({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'asia-south1');

  final FirebaseFunctions _functions;

  Future<Map<String, dynamic>> call(
    String name,
    Map<String, dynamic> data,
  ) async {
    final result = await _functions.httpsCallable(name).call(data);
    return Map<String, dynamic>.from(result.data as Map);
  }
}
