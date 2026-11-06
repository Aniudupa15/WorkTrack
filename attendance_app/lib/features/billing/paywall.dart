import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:attendance_app/core/billing/entitlements.dart';
import 'package:attendance_app/core/theme/app_colors.dart';
import 'package:attendance_app/core/theme/app_spacing.dart';
import 'package:attendance_app/core/widgets/app_button.dart';
import 'package:attendance_app/core/widgets/app_card.dart';
import 'package:attendance_app/core/widgets/entity_tile.dart';
import 'package:attendance_app/features/billing/choose_plan_screen.dart';
import 'package:attendance_app/features/shared/user_provider.dart';

/// Why an upgrade is needed, shown where a locked feature was tapped.
enum PaywallReason { export, morePeople, history, payroll }

/// Shows the upgrade sheet. Employees never see it — only admins reach the
/// features it guards.
Future<void> showPaywall(BuildContext context, PaywallReason reason) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _Paywall(reason: reason),
  );
}

class _Paywall extends StatelessWidget {
  const _Paywall({required this.reason});

  final PaywallReason reason;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final company = Provider.of<UserProvider>(context).company;
    final business = reason == PaywallReason.payroll;
    final tier = business ? Tier.business : Tier.pro;
    final people = (company?.activeEmployees ?? 1).clamp(1, 100000);
    final monthly = Pricing.perSeatMonthly(tier, BillingCycle.yearly) * people;

    final (String title, String body) = switch (reason) {
      PaywallReason.export => (
        'Export reports as CSV',
        'Download any month’s attendance as a CSV for payroll or audits.',
      ),
      PaywallReason.morePeople => (
        'Add more than ${Pricing.freeEmployeeLimit} people',
        'The Free plan covers ${Pricing.freeEmployeeLimit} people. Pro has no '
            'limit — you pay per person.',
      ),
      PaywallReason.history => (
        'See your full history',
        'The Free plan keeps the last ${Pricing.freeHistoryDays} days on '
            'screen. Older records are kept, not deleted.',
      ),
      PaywallReason.payroll => (
        'Send hours straight to payroll',
        'Export hours, late marks and leave to Tally, Zoho Payroll or Keka '
            'in one tap.',
      ),
    };

    final features = business
        ? const [
            (
              Icons.description_outlined,
              'Payroll export',
              'Tally, Zoho Payroll, Keka, CSV',
            ),
            (
              Icons.photo_camera_outlined,
              'Selfie verification',
              'No more buddy-punching',
            ),
            (
              Icons.how_to_reg_outlined,
              'Location managers',
              'Site heads approve their own team',
            ),
          ]
        : const [
            (
              Icons.groups_outlined,
              'Unlimited people',
              'Pay only for who you add',
            ),
            (Icons.history_rounded, 'Full history', 'Every punch, every month'),
            (
              Icons.ios_share_rounded,
              'CSV export',
              'Reports for payroll and audits',
            ),
          ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          0,
          AppSpacing.xl,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: colors.brandSoft,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  business ? 'Business plan' : 'Pro plan',
                  style: TextStyle(
                    color: colors.brandStrong,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(title, style: text.titleLarge),
            const SizedBox(height: AppSpacing.xs),
            Text(body, style: text.bodyMedium),
            const SizedBox(height: AppSpacing.lg),
            AppGroup(
              children: [
                for (final (icon, t, s) in features)
                  EntityTile(
                    inGroup: true,
                    leading: IconChip(icon: icon),
                    title: t,
                    subtitle: s,
                  ),
              ],
            ),
            if (!canBuyInApp) ...[
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: 'Got it',
                variant: AppButtonVariant.secondary,
                onPressed: () => Navigator.pop(context),
              ),
            ] else ...[
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: colors.surfaceMuted,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '$people × ${Pricing.format(Pricing.perSeatMonthly(tier, BillingCycle.yearly), whole: true)} / month, billed yearly',
                        style: text.bodySmall,
                      ),
                    ),
                    Text(
                      '${Pricing.format(monthly, whole: true)}/mo',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: 'Upgrade to ${business ? 'Business' : 'Pro'}',
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChoosePlanScreen(initial: tier),
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Trial countdown / trial-ended / payment-failed strip for the admin's
/// Today tab. Renders nothing when there's nothing to say.
class PlanBanner extends StatelessWidget {
  const PlanBanner({super.key, required this.onOpenBilling});

  final VoidCallback onOpenBilling;

  @override
  Widget build(BuildContext context) {
    final company = Provider.of<UserProvider>(context).company;
    final ent = Entitlements.of(company);
    final colors = context.colors;
    final String? message;
    var urgent = false;
    final choose = canBuyInApp ? ' Choose a plan.' : '';
    if (ent.isTrial && company?.billingStatus == null) {
      final days = ent.trialDaysLeft ?? 0;
      message = days <= 0
          ? 'Your Pro trial ends today.$choose'
          : 'Pro trial · $days ${days == 1 ? 'day' : 'days'} left.$choose';
      urgent = days <= 3;
    } else if (ent.trialEnded) {
      message = canBuyInApp
          ? 'Your trial ended — you’re on Free. Upgrade to keep Pro features.'
          : 'Your trial ended — you’re on the Free plan.';
      urgent = true;
    } else if (ent.paymentDue) {
      message = canBuyInApp
          ? 'Your last payment failed. Update your payment method.'
          : 'There’s a problem with your plan’s last payment.';
      urgent = true;
    } else {
      message = null;
    }
    if (message == null) return const SizedBox.shrink();
    final fg = urgent ? colors.warning : colors.brandStrong;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Material(
        color: urgent ? colors.warningSoft : colors.brandSoft,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: onOpenBilling,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Icon(Icons.workspace_premium_outlined, color: fg, size: 20),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    message,
                    style: TextStyle(color: fg, fontWeight: FontWeight.w600),
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: fg),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
