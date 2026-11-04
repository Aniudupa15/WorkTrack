import 'package:attendance_app/core/billing/entitlements.dart';
import 'package:attendance_app/core/error/app_exception.dart';
import 'package:attendance_app/data/datasources/billing_service.dart';
import 'package:attendance_app/domain/repositories/billing_repository.dart';

class BillingRepositoryImpl implements BillingRepository {
  BillingRepositoryImpl(this._service);

  final BillingService _service;

  @override
  Future<CheckoutSession> startCheckout({
    required String companyId,
    required Tier tier,
    required BillingCycle cycle,
    required int seats,
  }) async {
    final r = await _guard(
      () => _service.call('createSubscription', {
        'companyId': companyId,
        'plan': tier.name,
        'cycle': cycle.name,
        'seats': seats,
      }),
    );
    final startsAt = r['startsAt'] as num?;
    return CheckoutSession(
      subscriptionId: r['subscriptionId'] as String,
      keyId: r['keyId'] as String,
      fake: r['fake'] == true,
      startsAt: startsAt == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(startsAt.toInt()),
    );
  }

  @override
  Future<void> confirmCheckout({
    required String companyId,
    required String subscriptionId,
    required String paymentId,
    required String signature,
  }) => _guard(
    () => _service.call('verifySubscription', {
      'companyId': companyId,
      'subscriptionId': subscriptionId,
      'paymentId': paymentId,
      'signature': signature,
    }),
  );

  @override
  Future<void> cancel(String companyId) => _guard(
    () => _service.call('cancelSubscription', {'companyId': companyId}),
  );

  @override
  Future<List<Invoice>> invoices(String companyId) async {
    final r = await _guard(
      () => _service.call('listInvoices', {'companyId': companyId}),
    );
    return [
      for (final i in (r['invoices'] as List? ?? const []))
        Invoice(
          id: (i as Map)['id'] as String,
          amountPaise: (i['amount'] as num).toInt(),
          status: i['status'] as String? ?? '',
          date: DateTime.fromMillisecondsSinceEpoch((i['date'] as num).toInt()),
          url: i['url'] as String?,
        ),
    ];
  }

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } catch (error) {
      throw ErrorMapper.map(error);
    }
  }
}
