import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import 'package:attendance_app/core/billing/entitlements.dart';
import 'package:attendance_app/core/di/injection.dart';
import 'package:attendance_app/core/error/app_exception.dart';
import 'package:attendance_app/core/theme/app_colors.dart';
import 'package:attendance_app/core/theme/app_spacing.dart';
import 'package:attendance_app/core/widgets/app_button.dart';
import 'package:attendance_app/core/widgets/app_card.dart';
import 'package:attendance_app/core/widgets/entity_tile.dart';
import 'package:attendance_app/core/widgets/section_header.dart';
import 'package:attendance_app/domain/repositories/billing_repository.dart';
import 'package:attendance_app/features/shared/user_provider.dart';

/// Seats, the price breakdown with GST, and Razorpay Checkout. During the
/// trial nothing is charged today: Checkout only sets up the UPI AutoPay or
/// card mandate, and the first charge lands when the trial ends.
class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({
    super.key,
    required this.tier,
    required this.cycle,
    required this.seats,
  });

  final Tier tier;
  final BillingCycle cycle;
  final int seats;

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  late int _seats = widget.seats;
  late final int _minSeats = widget.seats;
  final _razorpay = Razorpay();
  CheckoutSession? _session;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onSuccess, rawMap: true);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _onError);
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  String get _companyId =>
      Provider.of<UserProvider>(context, listen: false).company?.id ?? '';

  Future<void> _start() async {
    final prov = Provider.of<UserProvider>(context, listen: false);
    setState(() => _busy = true);
    try {
      final session = await sl<BillingRepository>().startCheckout(
        companyId: _companyId,
        tier: widget.tier,
        cycle: widget.cycle,
        seats: _seats,
      );
      _session = session;
      if (session.fake) {
        // Emulator only: no Razorpay to open.
        await _confirm(session.subscriptionId, 'pay_emulator', 'emulator');
        return;
      }
      _razorpay.open({
        'key': session.keyId,
        'subscription_id': session.subscriptionId,
        'name': 'PunchIn',
        'description':
            '${_tierName(widget.tier)} · ${widget.cycle == BillingCycle.yearly ? 'Yearly' : 'Monthly'} · $_seats seats',
        'prefill': {'email': prov.user?.email ?? ''},
        'theme': {'color': '#0F766E'},
      });
    } catch (e) {
      _fail(e);
    }
  }

  void _onSuccess(dynamic response) {
    final data = Map<String, dynamic>.from(response as Map);
    _confirm(
      data['razorpay_subscription_id'] as String? ?? _session!.subscriptionId,
      data['razorpay_payment_id'] as String? ?? '',
      data['razorpay_signature'] as String? ?? '',
    );
  }

  void _onError(PaymentFailureResponse response) {
    if (!mounted) return;
    setState(() => _busy = false);
    if (response.code == Razorpay.PAYMENT_CANCELLED) return;
    _fail(AppException(response.message ?? 'The payment didn’t go through'));
  }

  Future<void> _confirm(
    String subscriptionId,
    String paymentId,
    String signature,
  ) async {
    try {
      await sl<BillingRepository>().confirmCheckout(
        companyId: _companyId,
        subscriptionId: subscriptionId,
        paymentId: paymentId,
        signature: signature,
      );
      if (!mounted) return;
      await Provider.of<UserProvider>(context, listen: false).refreshUser();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('You’re on ${_tierName(widget.tier)}')),
      );
      Navigator.popUntil(
        context,
        (r) => r.settings.name == 'billing' || r.isFirst,
      );
    } catch (e) {
      _fail(e);
    }
  }

  void _fail(Object e) {
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          e is AppException ? e.message : 'Couldn’t start checkout',
        ),
        backgroundColor: context.colors.danger,
      ),
    );
  }

  static String _tierName(Tier t) => t == Tier.business ? 'Business' : 'Pro';

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final ent = Entitlements.of(Provider.of<UserProvider>(context).company);
    final yearly = widget.cycle == BillingCycle.yearly;
    final perSeat = Pricing.perSeat(widget.tier, widget.cycle).toDouble();
    final subtotal = Pricing.subtotal(widget.tier, widget.cycle, _seats);
    final gst = Pricing.gst(widget.tier, widget.cycle, _seats);
    final total = Pricing.total(widget.tier, widget.cycle, _seats);
    final trialEnd = ent.isTrial ? ent.company?.trialEndsAt : null;
    final chargeDay = trialEnd == null
        ? 'today'
        : 'on ${DateFormat('d MMM').format(trialEnd)}';

    Widget line(String label, String value, {bool strong = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: strong
                  ? const TextStyle(fontWeight: FontWeight.w700)
                  : text.bodySmall,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: strong ? FontWeight.w700 : FontWeight.w500,
              fontSize: strong ? 17 : 14,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
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
                          Text(
                            '${_tierName(widget.tier)} · ${yearly ? 'Yearly' : 'Monthly'}',
                            style: text.titleMedium,
                          ),
                          Text(
                            trialEnd == null
                                ? 'Billed ${yearly ? 'yearly' : 'monthly'}'
                                : 'Trial until ${DateFormat('d MMM').format(trialEnd)}, then billed ${yearly ? 'yearly' : 'monthly'}',
                            style: text.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Change'),
                    ),
                  ],
                ),
                Divider(color: colors.border, height: AppSpacing.xl),
                Row(
                  children: [
                    const Expanded(child: Text('Seats')),
                    _Stepper(
                      value: _seats,
                      min: _minSeats,
                      onChanged: (v) => setState(() => _seats = v),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                line(
                  '$_seats × ${Pricing.format(perSeat, whole: true)}${yearly ? ' × 1 year' : ' × 1 month'}',
                  Pricing.format(subtotal),
                ),
                line(
                  'GST (${(Pricing.gstRate * 100).round()}%)',
                  Pricing.format(gst),
                ),
                Divider(color: colors.border, height: AppSpacing.lg),
                line('Total $chargeDay', Pricing.format(total), strong: true),
                if (trialEnd != null)
                  Row(
                    children: [
                      Expanded(child: Text('Due today', style: text.bodySmall)),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: colors.successSoft,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '₹0',
                          style: TextStyle(
                            color: colors.success,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SectionHeader(title: 'Payment method'),
          const SizedBox(height: AppSpacing.sm),
          const AppGroup(
            children: [
              EntityTile(
                inGroup: true,
                leading: IconChip(icon: Icons.bolt_rounded),
                title: 'UPI AutoPay',
                subtitle: 'GPay, PhonePe, Paytm and more',
              ),
              EntityTile(
                inGroup: true,
                leading: IconChip(icon: Icons.credit_card_rounded),
                title: 'Credit or debit card',
                subtitle: 'Visa, Mastercard, RuPay',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Icon(
                Icons.lock_outline_rounded,
                size: 16,
                color: colors.textTertiary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'You choose the method in Razorpay’s secure checkout. '
                  'Cancel any time from Billing.',
                  style: text.labelSmall,
                ),
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: AppButton(
            label: trialEnd != null
                ? 'Start trial & set up AutoPay'
                : 'Pay ${Pricing.format(total)}',
            loading: _busy,
            onPressed: _busy ? null : _start,
          ),
        ),
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.value,
    required this.min,
    required this.onChanged,
  });

  final int value;
  final int min;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Fewer seats',
            visualDensity: VisualDensity.compact,
            onPressed: value > min ? () => onChanged(value - 1) : null,
            icon: const Icon(Icons.remove_rounded, size: 18),
          ),
          SizedBox(
            width: 32,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(
            tooltip: 'More seats',
            visualDensity: VisualDensity.compact,
            onPressed: value < 10000 ? () => onChanged(value + 1) : null,
            icon: const Icon(Icons.add_rounded, size: 18),
          ),
        ],
      ),
    );
  }
}
