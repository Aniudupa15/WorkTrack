import 'package:intl/intl.dart';

import 'package:attendance_app/data/models/company_model.dart';

/// What a company may use right now. Mirrors `effectiveTier` in the Cloud
/// Functions and `onFreeTier` in the Security Rules, which enforce the same
/// limits server-side.
enum Tier {
  /// Created before billing existed: unrestricted until the owner chooses.
  legacy,
  trial,
  free,
  pro,
  business,
}

enum BillingCycle { monthly, yearly }

/// Per-seat prices (₹, before GST). Keep in sync with PRICES in
/// cloud_functions/index.js and the Razorpay plans.
class Pricing {
  const Pricing._();

  static const freeEmployeeLimit = 5;
  static const freeHistoryDays = 30;
  static const gstRate = 0.18;
  static const yearlyDiscountPercent = 20;

  static int perSeat(Tier tier, BillingCycle cycle) => switch ((tier, cycle)) {
    (Tier.pro, BillingCycle.monthly) => 39,
    (Tier.pro, BillingCycle.yearly) => 374,
    (Tier.business, BillingCycle.monthly) => 79,
    (Tier.business, BillingCycle.yearly) => 758,
    _ => 0,
  };

  /// Per seat per month, for comparing cycles (yearly shows the discount).
  static double perSeatMonthly(Tier tier, BillingCycle cycle) =>
      cycle == BillingCycle.yearly
      ? perSeat(tier, cycle) / 12
      : perSeat(tier, cycle).toDouble();

  static double subtotal(Tier tier, BillingCycle cycle, int seats) =>
      (perSeat(tier, cycle) * seats).toDouble();

  static double gst(Tier tier, BillingCycle cycle, int seats) =>
      _round(subtotal(tier, cycle, seats) * gstRate);

  static double total(Tier tier, BillingCycle cycle, int seats) =>
      subtotal(tier, cycle, seats) + gst(tier, cycle, seats);

  static double _round(double v) => (v * 100).roundToDouble() / 100;

  static final _inr = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );
  static final _inrWhole = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  /// ₹5,616.00 — or ₹5,616 with [whole].
  static String format(double amount, {bool whole = false}) =>
      (whole ? _inrWhole : _inr).format(amount);
}

class Entitlements {
  const Entitlements._(this.tier, this.company, this.now);

  factory Entitlements.of(CompanyModel? company, {DateTime? now}) {
    final at = now ?? DateTime.now();
    return Entitlements._(_tierOf(company, at), company, at);
  }

  final Tier tier;
  final CompanyModel? company;
  final DateTime now;

  static const _live = {'authenticated', 'active', 'pending'};

  static Tier _tierOf(CompanyModel? c, DateTime now) {
    switch (c?.plan) {
      case null:
        return Tier.legacy;
      case 'trial':
        final end = c!.trialEndsAt;
        return end != null && end.isAfter(now) ? Tier.trial : Tier.free;
      case 'pro':
      case 'business':
        if (!_live.contains(c!.billingStatus)) return Tier.free;
        return c.plan == 'pro' ? Tier.pro : Tier.business;
      default:
        return Tier.free;
    }
  }

  bool get isFree => tier == Tier.free;
  bool get isTrial => tier == Tier.trial;

  /// A paid plan whose payments are current.
  bool get isPaid => tier == Tier.pro || tier == Tier.business;

  /// Pro features (exports, unlimited people and history): trial, Pro,
  /// Business, and pre-billing companies.
  bool get hasPro => !isFree;

  /// Business features (payroll export, selfie review, location managers).
  bool get hasBusiness =>
      tier == Tier.business || tier == Tier.trial || tier == Tier.legacy;

  /// The trial ran out without a subscription.
  bool get trialEnded => company?.plan == 'trial' && tier == Tier.free;

  /// Whole days of trial left (0 on the last day), or null outside a trial.
  int? get trialDaysLeft {
    final end = company?.trialEndsAt;
    if (!isTrial || end == null) return null;
    return end.difference(now).inHours ~/ 24;
  }

  int? get maxPeople => isFree ? Pricing.freeEmployeeLimit : null;

  bool canAddPeople(int current) => maxPeople == null || current < maxPeople!;

  /// Oldest attendance day an admin can see (`yyyy-MM-dd`), or null for all
  /// of it. One day inside the server's 30-day line so queries never cross it.
  String? get historySince => isFree
      ? DateFormat('yyyy-MM-dd').format(
          now
              .toUtc()
              .add(const Duration(minutes: 330))
              .subtract(const Duration(days: Pricing.freeHistoryDays - 1)),
        )
      : null;

  /// Payment failed and Razorpay is retrying.
  bool get paymentDue => company?.billingStatus == 'pending';

  String get planName => switch (tier) {
    Tier.legacy => 'Classic',
    Tier.trial => 'Pro trial',
    Tier.free => 'Free',
    Tier.pro => 'Pro',
    Tier.business => 'Business',
  };
}
