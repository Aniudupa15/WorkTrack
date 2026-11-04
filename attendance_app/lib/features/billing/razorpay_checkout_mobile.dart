import 'dart:async';

import 'package:razorpay_flutter/razorpay_flutter.dart';

import 'package:attendance_app/features/billing/razorpay_checkout.dart';

/// Opens the native Razorpay Checkout. Completes with the result, with null
/// when the customer closes it, or with a [RazorpayFailure].
Future<RazorpayResult?> openRazorpayCheckout(Map<String, dynamic> options) {
  final razorpay = Razorpay();
  final completer = Completer<RazorpayResult?>();
  void finish(void Function() done) {
    if (completer.isCompleted) return;
    done();
    razorpay.clear();
  }

  razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, (dynamic response) {
    final data = Map<String, dynamic>.from(response as Map);
    finish(
      () => completer.complete(
        RazorpayResult(
          paymentId: data['razorpay_payment_id'] as String? ?? '',
          subscriptionId:
              data['razorpay_subscription_id'] as String? ??
              options['subscription_id'] as String,
          signature: data['razorpay_signature'] as String? ?? '',
        ),
      ),
    );
  }, rawMap: true);
  razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, (PaymentFailureResponse r) {
    finish(
      () => r.code == Razorpay.PAYMENT_CANCELLED
          ? completer.complete(null)
          : completer.completeError(
              RazorpayFailure(r.message ?? 'The payment didn’t go through'),
            ),
    );
  });
  razorpay.open(options);
  return completer.future;
}
