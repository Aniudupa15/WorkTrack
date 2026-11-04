import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:attendance_app/features/billing/razorpay_checkout.dart';

/// `new Razorpay(options)` from https://checkout.razorpay.com/v1/checkout.js.
@JS('Razorpay')
extension type _Razorpay._(JSObject _) implements JSObject {
  external factory _Razorpay(JSObject options);
  external void open();
  external void on(String event, JSFunction handler);
}

/// Opens Razorpay's web Checkout. Completes with the result, with null when
/// the customer closes it, or with a [RazorpayFailure].
Future<RazorpayResult?> openRazorpayCheckout(Map<String, dynamic> options) {
  if (!globalContext.has('Razorpay')) {
    return Future.error(
      const RazorpayFailure('Couldn’t load Razorpay. Check your connection.'),
    );
  }
  final completer = Completer<RazorpayResult?>();

  final js = (options..remove('handler')).jsify()! as JSObject;
  js['handler'] = ((JSObject r) {
    String read(String key) => (r[key] as JSString?)?.toDart ?? '';
    if (!completer.isCompleted) {
      completer.complete(
        RazorpayResult(
          paymentId: read('razorpay_payment_id'),
          subscriptionId: read('razorpay_subscription_id').isNotEmpty
              ? read('razorpay_subscription_id')
              : options['subscription_id'] as String,
          signature: read('razorpay_signature'),
        ),
      );
    }
  }).toJS;
  final modal = (js['modal'] as JSObject?) ?? JSObject();
  modal['ondismiss'] = (() {
    if (!completer.isCompleted) completer.complete(null);
  }).toJS;
  js['modal'] = modal;

  final checkout = _Razorpay(js);
  checkout.on(
    'payment.failed',
    ((JSObject r) {
      final error = r['error'] as JSObject?;
      final message =
          (error?['description'] as JSString?)?.toDart ??
          'The payment didn’t go through';
      if (!completer.isCompleted) {
        completer.completeError(RazorpayFailure(message));
      }
    }).toJS,
  );
  checkout.open();
  return completer.future;
}
