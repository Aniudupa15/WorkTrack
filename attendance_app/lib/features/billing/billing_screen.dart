import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:attendance_app/core/billing/entitlements.dart';
import 'package:attendance_app/core/di/injection.dart';
import 'package:attendance_app/core/error/app_exception.dart';
import 'package:attendance_app/core/theme/app_colors.dart';
import 'package:attendance_app/core/theme/app_spacing.dart';
import 'package:attendance_app/core/widgets/app_button.dart';
import 'package:attendance_app/core/widgets/app_card.dart';
import 'package:attendance_app/core/widgets/entity_tile.dart';
import 'package:attendance_app/core/widgets/section_header.dart';
import 'package:attendance_app/core/widgets/status_badge.dart';
import 'package:attendance_app/domain/repositories/billing_repository.dart';
import 'package:attendance_app/features/billing/choose_plan_screen.dart';
import 'package:attendance_app/features/shared/user_provider.dart';

/// Opens Billing as a named route so Checkout can return straight to it.
Future<void> openBilling(BuildContext context) => Navigator.push(
  context,
  MaterialPageRoute(
    settings: const RouteSettings(name: 'billing'),
    builder: (_) => const BillingScreen(),
  ),
);

/// Current plan, seats, invoices and cancellation.
class BillingScreen extends StatefulWidget {
  const BillingScreen({super.key});

  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> {
  Future<List<Invoice>>? _invoices;
  bool _cancelling = false;

  @override
  void initState() {
    super.initState();
    final prov = Provider.of<UserProvider>(context, listen: false);
    prov.refreshUser();
    if (Entitlements.of(prov.company).isPaid) {
      _invoices = sl<BillingRepository>().invoices(prov.company!.id);
    }
  }

  Future<void> _cancel() async {
    final prov = Provider.of<UserProvider>(context, listen: false);
    final end = prov.company?.currentPeriodEnd;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel your subscription?'),
        content: Text(
          end == null
              ? 'You keep your plan until the end of the period you paid '
                    'for, then move to Free.'
              : 'You keep your plan until ${DateFormat('d MMM yyyy').format(end)}, '
                    'then move to Free (5 people, 30 days of history).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep plan'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Cancel subscription',
              style: TextStyle(color: context.colors.danger),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _cancelling = true);
    try {
      await sl<BillingRepository>().cancel(prov.company!.id);
      await prov.refreshUser();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e is AppException ? e.message : 'Couldn’t cancel'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  void _choose(Tier tier) => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => ChoosePlanScreen(initial: tier)),
  );

  @override
  Widget build(BuildContext context) {
    final company = Provider.of<UserProvider>(context).company;
    final ent = Entitlements.of(company);
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final date = DateFormat('d MMM yyyy');
    final people = company?.activeEmployees ?? 0;
    final cycle = company?.cycle == 'monthly' ? 'Monthly' : 'Yearly';

    final (String pillStatus, String pillLabel) = switch (ent.tier) {
      Tier.trial => ('late', 'Trial · ${ent.trialDaysLeft} days left'),
      Tier.free => ('absent', ent.trialEnded ? 'Trial ended' : 'Free'),
      Tier.legacy => ('present', 'Active'),
      _ when ent.paymentDue => ('absent', 'Payment due'),
      _ when company?.billingStatus == 'authenticated' => (
        'present',
        'AutoPay set up',
      ),
      _ when company?.cancelAtPeriodEnd == true => ('late', 'Cancelling'),
      _ => ('present', 'Active'),
    };

    final String? note = switch (ent.tier) {
      Tier.trial when company?.billingStatus == 'authenticated' =>
        'AutoPay is set up. First charge on ${date.format(company!.trialEndsAt!)}.',
      Tier.trial when !canBuyInApp =>
        'Your Pro trial runs until ${date.format(company!.trialEndsAt!)}, '
            'then you move to Free.',
      Tier.trial =>
        'Choose a plan before ${date.format(company!.trialEndsAt!)} to keep '
            'Pro features. Otherwise you move to Free.',
      Tier.free =>
        'Free includes ${Pricing.freeEmployeeLimit} people and '
            '${Pricing.freeHistoryDays} days of history.',
      _
          when company?.billingStatus == 'authenticated' &&
              (company?.trialEndsAt?.isAfter(DateTime.now()) ?? false) =>
        'AutoPay is set up. Your trial runs until '
            '${date.format(company!.trialEndsAt!)}, then the first charge.',
      _ when company?.billingStatus == 'authenticated' =>
        'AutoPay is set up. The first charge is on its way.',
      _ when ent.paymentDue && !canBuyInApp =>
        'There’s a problem with your plan’s last payment.',
      _ when ent.paymentDue =>
        'Your last payment failed. Razorpay will retry — update your UPI or '
            'card in the Razorpay email to avoid losing access.',
      _
          when company?.cancelAtPeriodEnd == true &&
              company?.currentPeriodEnd != null =>
        'Ends on ${date.format(company!.currentPeriodEnd!)}, then Free.',
      _ when company?.currentPeriodEnd != null =>
        'Renews on ${date.format(company!.currentPeriodEnd!)}.',
      _ => null,
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Billing')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Current plan', style: text.bodySmall),
                          Text(
                            ent.isPaid
                                ? '${ent.planName} · $cycle'
                                : ent.planName,
                            style: text.titleLarge,
                          ),
                        ],
                      ),
                    ),
                    StatusBadge(status: pillStatus, label: pillLabel),
                  ],
                ),
                if (note != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: colors.surfaceMuted,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Text(note, style: text.bodySmall),
                  ),
                ],
                if (canBuyInApp && ent.tier != Tier.legacy) ...[
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: AppButton(
                          label: ent.isPaid ? 'Change plan' : 'See plans',
                          size: AppButtonSize.small,
                          variant: ent.isPaid
                              ? AppButtonVariant.secondary
                              : AppButtonVariant.primary,
                          onPressed: () => _choose(Tier.pro),
                        ),
                      ),
                      if (ent.tier == Tier.pro) ...[
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: AppButton(
                            label: 'Go Business',
                            size: AppButtonSize.small,
                            onPressed: () => _choose(Tier.business),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: _Usage(ent: ent, people: people, seats: company?.seats ?? 0),
          ),
          if (_invoices != null) ...[
            const SectionHeader(title: 'Invoices'),
            const SizedBox(height: AppSpacing.sm),
            FutureBuilder<List<Invoice>>(
              future: _invoices,
              builder: (context, snap) {
                final list = snap.data ?? const <Invoice>[];
                return AppGroup(
                  children: [
                    if (list.isEmpty)
                      EntityTile(
                        inGroup: true,
                        title: snap.connectionState == ConnectionState.waiting
                            ? 'Loading…'
                            : 'No invoices yet',
                        subtitle: 'Invoices appear here after each payment',
                      ),
                    for (final i in list)
                      EntityTile(
                        inGroup: true,
                        leading: const IconChip(
                          icon: Icons.receipt_long_rounded,
                        ),
                        title: Pricing.format(i.amountPaise / 100),
                        subtitle:
                            '${date.format(i.date)} · ${StatusBadge.humanise(i.status)}',
                        chevron: i.url != null,
                        onTap: i.url == null
                            ? null
                            : () => launchUrl(
                                Uri.parse(i.url!),
                                mode: LaunchMode.externalApplication,
                              ),
                      ),
                  ],
                );
              },
            ),
          ],
          if (ent.isPaid && company?.cancelAtPeriodEnd != true) ...[
            const SizedBox(height: AppSpacing.xl),
            TextButton(
              onPressed: _cancelling ? null : _cancel,
              child: Text(
                _cancelling ? 'Cancelling…' : 'Cancel subscription',
                style: TextStyle(color: colors.danger),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Usage extends StatelessWidget {
  const _Usage({required this.ent, required this.people, required this.seats});

  final Entitlements ent;
  final int people;
  final int seats;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final limit = ent.isFree
        ? Pricing.freeEmployeeLimit
        : (ent.isPaid ? seats : null);
    final share = limit == null || limit == 0
        ? 0.0
        : (people / limit).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                ent.isPaid ? 'Seats' : 'People',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            Text(
              limit == null ? '$people' : '$people of $limit used',
              style: text.bodySmall,
            ),
          ],
        ),
        if (limit != null) ...[
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: share,
              minHeight: 8,
              backgroundColor: colors.surfaceMuted,
              color: share >= 1 ? colors.warning : colors.brand,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        Text(
          ent.isPaid
              ? 'Adding people adds seats automatically from your next bill.'
              : ent.isFree
              ? (canBuyInApp
                    ? 'Upgrade to add more than ${Pricing.freeEmployeeLimit} people.'
                    : 'Free includes up to ${Pricing.freeEmployeeLimit} people.')
              : ent.isTrial
              ? 'No limit during your trial.'
              : 'No limit on your plan.',
          style: text.labelSmall,
        ),
      ],
    );
  }
}
