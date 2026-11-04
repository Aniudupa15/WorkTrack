import 'package:attendance_app/core/billing/entitlements.dart';

/// Razorpay subscriptions for a company.
abstract interface class BillingRepository {
  /// Creates a Razorpay subscription to open in Checkout.
  Future<CheckoutSession> startCheckout({
    required String companyId,
    required Tier tier,
    required BillingCycle cycle,
    required int seats,
  });

  /// Confirms a completed Checkout with Razorpay's signature.
  Future<void> confirmCheckout({
    required String companyId,
    required String subscriptionId,
    required String paymentId,
    required String signature,
  });

  /// Cancels at the end of the paid period.
  Future<void> cancel(String companyId);

  Future<List<Invoice>> invoices(String companyId);
}

class CheckoutSession {
  const CheckoutSession({
    required this.subscriptionId,
    required this.keyId,
    required this.fake,
    this.startsAt,
  });

  final String subscriptionId;
  final String keyId;

  /// The emulator's stand-in for Razorpay: there is no Checkout to open.
  final bool fake;

  /// When the first charge happens (end of trial), or null for now.
  final DateTime? startsAt;
}

class Invoice {
  const Invoice({
    required this.id,
    required this.amountPaise,
    required this.status,
    required this.date,
    this.url,
  });

  final String id;
  final int amountPaise;
  final String status;
  final DateTime date;
  final String? url;
}
