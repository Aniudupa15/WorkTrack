import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:attendance_app/core/billing/entitlements.dart';
import 'package:attendance_app/core/theme/app_colors.dart';
import 'package:attendance_app/core/theme/app_spacing.dart';
import 'package:attendance_app/core/widgets/app_button.dart';
import 'package:attendance_app/core/widgets/app_chip.dart';
import 'package:attendance_app/core/widgets/app_page.dart';
import 'package:attendance_app/core/widgets/pressable.dart';
import 'package:attendance_app/features/billing/checkout_screen.dart';
import 'package:attendance_app/features/shared/user_provider.dart';

/// Free / Pro / Business, monthly or yearly.
class ChoosePlanScreen extends StatefulWidget {
  const ChoosePlanScreen({super.key, this.initial = Tier.pro});

  final Tier initial;

  @override
  State<ChoosePlanScreen> createState() => _ChoosePlanScreenState();
}

class _ChoosePlanScreenState extends State<ChoosePlanScreen> {
  late Tier _tier = widget.initial == Tier.business ? Tier.business : Tier.pro;
  BillingCycle _cycle = BillingCycle.yearly;

  @override
  Widget build(BuildContext context) {
    final company = Provider.of<UserProvider>(context).company;
    final ent = Entitlements.of(company);
    final seats = company?.activeEmployees ?? company?.totalEmployees ?? 1;
    final people = seats < 1 ? 1 : seats;
    final months = _cycle == BillingCycle.yearly ? 12 : 1;
    final paid = _tier != Tier.free;

    return Scaffold(
      appBar: AppBar(title: const Text('Choose a plan')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        children: [
          if (ent.isTrial) ...[
            AppBanner(
              icon: Icons.card_giftcard_rounded,
              child: Text(
                'Your Pro trial has ${ent.trialDaysLeft} days left. Pick what '
                'to continue with — nothing is charged today.',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          AppSegmented<BillingCycle>(
            selected: _cycle,
            onChanged: (c) => setState(() => _cycle = c),
            segments: const {
              BillingCycle.monthly: 'Monthly',
              BillingCycle.yearly: 'Yearly · save 20%',
            },
          ),
          const SizedBox(height: AppSpacing.md),
          _PlanCard(
            title: 'Free',
            price: '₹0',
            selected: _tier == Tier.free,
            features: const [
              'Up to ${Pricing.freeEmployeeLimit} employees',
              '${Pricing.freeHistoryDays} days of history',
            ],
            onTap: () => setState(() => _tier = Tier.free),
          ),
          const SizedBox(height: AppSpacing.md),
          _PlanCard(
            title: 'Pro',
            badge: 'Recommended',
            price: Pricing.format(
              Pricing.perSeatMonthly(Tier.pro, _cycle),
              whole: true,
            ),
            unit: 'per employee / mo',
            selected: _tier == Tier.pro,
            features: const [
              'Unlimited employees and history',
              'Reports with CSV export',
              'Leave approvals and shift reminders',
            ],
            onTap: () => setState(() => _tier = Tier.pro),
          ),
          const SizedBox(height: AppSpacing.md),
          _PlanCard(
            title: 'Business',
            price: Pricing.format(
              Pricing.perSeatMonthly(Tier.business, _cycle),
              whole: true,
            ),
            unit: 'per employee / mo',
            selected: _tier == Tier.business,
            features: const [
              'Everything in Pro, plus selfie verification',
              'Payroll export and location managers',
            ],
            onTap: () => setState(() => _tier = Tier.business),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'All plans include unlimited work locations. Prices exclude 18% GST.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: context.colors.surface,
            border: Border(top: BorderSide(color: context.colors.border)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (paid)
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '$people × ${Pricing.format(Pricing.perSeat(_tier, _cycle).toDouble(), whole: true)}'
                        '${months == 12 ? ' / year' : ' / month'}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    Text(
                      '${Pricing.format(Pricing.subtotal(_tier, _cycle, people), whole: true)}'
                      '${months == 12 ? '/yr' : '/mo'}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              if (paid) const SizedBox(height: AppSpacing.sm),
              AppButton(
                label: paid
                    ? 'Continue with ${_tier == Tier.pro ? 'Pro' : 'Business'}'
                    : (ent.isTrial
                          ? 'Move to Free after the trial'
                          : 'Stay on Free'),
                onPressed: paid
                    ? () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CheckoutScreen(
                            tier: _tier,
                            cycle: _cycle,
                            seats: people,
                          ),
                        ),
                      )
                    : () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.title,
    required this.price,
    required this.selected,
    required this.features,
    required this.onTap,
    this.badge,
    this.unit,
  });

  final String title;
  final String price;
  final String? unit;
  final String? badge;
  final bool selected;
  final List<String> features;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    return Pressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: selected ? colors.brandSoft : colors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: selected ? colors.brand : colors.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: text.titleMedium),
                if (badge != null) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: colors.brand,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      badge!,
                      style: TextStyle(
                        color: colors.onBrand,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      price,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (unit != null) Text(unit!, style: text.labelSmall),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            for (final f in features)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check_rounded, size: 18, color: colors.brand),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(child: Text(f, style: text.bodySmall)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
