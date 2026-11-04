import 'package:flutter_test/flutter_test.dart';

import 'package:attendance_app/core/billing/entitlements.dart';
import 'package:attendance_app/data/models/company_model.dart';

CompanyModel company({String? plan, String? status, DateTime? trialEndsAt}) =>
    CompanyModel(
      id: 'c',
      companyName: 'Acme',
      adminId: 'a',
      plan: plan,
      billingStatus: status,
      trialEndsAt: trialEndsAt,
    );

void main() {
  final now = DateTime.utc(2026, 11, 4, 6);

  test('tier follows plan, trial end and payment status', () {
    Tier tier(CompanyModel c) => Entitlements.of(c, now: now).tier;
    expect(tier(company()), Tier.legacy);
    expect(
      tier(
        company(plan: 'trial', trialEndsAt: now.add(const Duration(days: 3))),
      ),
      Tier.trial,
    );
    expect(
      tier(
        company(
          plan: 'trial',
          trialEndsAt: now.subtract(const Duration(hours: 1)),
        ),
      ),
      Tier.free,
    );
    expect(tier(company(plan: 'pro', status: 'active')), Tier.pro);
    expect(tier(company(plan: 'pro', status: 'pending')), Tier.pro);
    expect(
      tier(company(plan: 'business', status: 'authenticated')),
      Tier.business,
    );
    expect(tier(company(plan: 'pro', status: 'halted')), Tier.free);
    expect(tier(company(plan: 'free')), Tier.free);
  });

  test('Free is capped at 5 people and 30 days; others are not', () {
    final free = Entitlements.of(company(plan: 'free'), now: now);
    expect(free.canAddPeople(4), isTrue);
    expect(free.canAddPeople(5), isFalse);
    expect(free.historySince, '2026-10-06');
    expect(free.hasPro, isFalse);

    final pro = Entitlements.of(
      company(plan: 'pro', status: 'active'),
      now: now,
    );
    expect(pro.canAddPeople(500), isTrue);
    expect(pro.historySince, isNull);
    expect(pro.hasPro, isTrue);
    expect(pro.hasBusiness, isFalse);
  });

  test('trial shows days left and every feature', () {
    final e = Entitlements.of(
      company(
        plan: 'trial',
        trialEndsAt: now.add(const Duration(days: 11, hours: 3)),
      ),
      now: now,
    );
    expect(e.trialDaysLeft, 11);
    expect(e.hasBusiness, isTrue);
    final ended = Entitlements.of(
      company(
        plan: 'trial',
        trialEndsAt: now.subtract(const Duration(days: 1)),
      ),
      now: now,
    );
    expect(ended.trialEnded, isTrue);
  });

  test('pricing: yearly is 20% off; GST is 18%', () {
    expect(
      Pricing.perSeatMonthly(Tier.pro, BillingCycle.yearly),
      closeTo(39, 0.01),
    );
    expect(Pricing.subtotal(Tier.pro, BillingCycle.monthly, 12), 588);
    expect(Pricing.gst(Tier.pro, BillingCycle.monthly, 12), 105.84);
    // Matches the Checkout mockup: 12 × ₹39 × 12 months + GST.
    expect(Pricing.total(Tier.pro, BillingCycle.yearly, 12), 6626.88);
    expect(Pricing.format(6626.88), '₹6,626.88');
  });
}
