/// Opens Razorpay Checkout for a subscription. The phone apps use the
/// razorpay_flutter SDK; the web app uses Razorpay's checkout.js (loaded in
/// web/index.html).
library;

export 'razorpay_checkout_mobile.dart'
    if (dart.library.js_interop) 'razorpay_checkout_web.dart';

/// What Checkout returns when the customer completes it.
class RazorpayResult {
  const RazorpayResult({
    required this.paymentId,
    required this.subscriptionId,
    required this.signature,
  });

  final String paymentId;
  final String subscriptionId;
  final String signature;
}

/// Checkout failed (not cancelled) — [message] is Razorpay's reason.
class RazorpayFailure implements Exception {
  const RazorpayFailure(this.message);

  final String message;
}
