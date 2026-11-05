import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:attendance_app/core/billing/entitlements.dart';

import 'package:attendance_app/core/di/injection.dart';
import 'package:attendance_app/core/theme/app_colors.dart';
import 'package:attendance_app/core/theme/app_spacing.dart';
import 'package:attendance_app/core/widgets/app_button.dart';
import 'package:attendance_app/core/widgets/app_card.dart';
import 'package:attendance_app/core/widgets/app_loader.dart';
import 'package:attendance_app/core/widgets/app_page.dart';
import 'package:attendance_app/core/widgets/app_search_field.dart';
import 'package:attendance_app/core/widgets/avatar.dart';
import 'package:attendance_app/core/widgets/empty_state.dart';
import 'package:attendance_app/core/widgets/entity_tile.dart';
import 'package:attendance_app/core/widgets/status_badge.dart';
import 'package:attendance_app/data/models/company_model.dart';
import 'package:attendance_app/domain/repositories/company_repository.dart';
import 'package:attendance_app/features/admin/add_company.dart';
import 'package:attendance_app/features/shared/user_provider.dart';

/// Super-admin home: revenue, plan mix and the roster of every company, with
/// the ability to provision new ones and suspend/activate existing ones.
class SuperAdminConsole extends StatefulWidget {
  const SuperAdminConsole({super.key});

  @override
  State<SuperAdminConsole> createState() => _SuperAdminConsoleState();
}

enum _Kind { paying, trial, free, pastDue }

class _SuperAdminConsoleState extends State<SuperAdminConsole> {
  final _repo = sl<CompanyRepository>();
  late final Stream<List<CompanyModel>> _companies = _repo.watchCompanies();
  String _query = '';

  static _Kind _kindOf(CompanyModel c) {
    if (c.plan == 'pro' || c.plan == 'business') {
      if (c.billingStatus == 'pending' || c.billingStatus == 'halted') {
        return _Kind.pastDue;
      }
      return Entitlements.of(c).isPaid ? _Kind.paying : _Kind.free;
    }
    return Entitlements.of(c).isTrial ? _Kind.trial : _Kind.free;
  }

  /// Monthly value of a paying company (₹, before GST).
  static double _mrrOf(CompanyModel c) {
    if (_kindOf(c) != _Kind.paying) return 0;
    final tier = c.plan == 'business' ? Tier.business : Tier.pro;
    final cycle = c.cycle == 'yearly'
        ? BillingCycle.yearly
        : BillingCycle.monthly;
    return Pricing.perSeatMonthly(tier, cycle) * c.seats;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      appBar: TabHeader(
        title: 'Console',
        actions: [
          const StatusBadge(status: 'brand', label: 'Super admin', dot: false),
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout_rounded),
            onPressed: () =>
                Provider.of<UserProvider>(context, listen: false).signOut(),
          ),
        ],
      ),
      body: StreamBuilder<List<CompanyModel>>(
        stream: _companies,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const AppLoader();
          }
          final companies = snap.data ?? [];
          final count = {for (final k in _Kind.values) k: 0};
          for (final c in companies) {
            count[_kindOf(c)] = count[_kindOf(c)]! + 1;
          }
          final mrr = companies.fold<double>(0, (a, c) => a + _mrrOf(c));
          final q = _query.toLowerCase();
          final shown = companies
              .where(
                (c) =>
                    q.isEmpty ||
                    c.name.toLowerCase().contains(q) ||
                    c.adminEmail.toLowerCase().contains(q),
              )
              .toList();

          Widget stat(String label, int n, Color dot) => Expanded(
            child: AppCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              radius: AppRadius.md,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: dot,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        label,
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$n',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          );

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.xs,
              AppSpacing.lg,
              100,
            ),
            children: [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Monthly recurring revenue',
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      Pricing.format(mrr, whole: true),
                      style: const TextStyle(
                        fontSize: 30,
                        height: 36 / 30,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.6,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    Text(
                      'From live subscriptions, before GST · yearly plans '
                      'counted per month',
                      style: TextStyle(
                        color: colors.textTertiary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  stat('Paying', count[_Kind.paying]!, colors.success),
                  const SizedBox(width: AppSpacing.sm),
                  stat(
                    'On trial',
                    count[_Kind.trial]!,
                    const Color(0xFFF59E0B),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  stat('Free', count[_Kind.free]!, colors.textTertiary),
                  const SizedBox(width: AppSpacing.sm),
                  stat('Past due', count[_Kind.pastDue]!, colors.danger),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              AppSearchField(
                hint: 'Search companies',
                onChanged: (v) => setState(() => _query = v),
              ),
              const SizedBox(height: AppSpacing.md),
              if (companies.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: AppSpacing.xxl),
                  child: EmptyState(
                    icon: Icons.domain_add_rounded,
                    title: 'No companies yet',
                    subtitle: 'Create the first workspace to get started.',
                  ),
                )
              else
                AppGroup(
                  children: [
                    for (final c in shown)
                      EntityTile(
                        inGroup: true,
                        leading: Avatar(name: c.name, square: true),
                        title: c.name,
                        subtitle: _subtitle(c),
                        trailing: _pill(c),
                        onTap: () => _showSheet(context, _repo, c),
                      ),
                  ],
                ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddCompany()),
        ),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add company'),
      ),
    );
  }

  String _subtitle(CompanyModel c) {
    final people = '${c.activeEmployees} people';
    if (c.status == 'suspended') return '$people · suspended';
    final e = Entitlements.of(c);
    switch (_kindOf(c)) {
      case _Kind.trial:
        return '$people · trial ends '
            '${DateFormat('d MMM').format(c.trialEndsAt!)}';
      case _Kind.paying:
        return '${c.seats} seats · ${c.plan == 'business' ? 'Business' : 'Pro'} '
            '${c.cycle == 'yearly' ? 'yearly' : 'monthly'}';
      case _Kind.pastDue:
        return '${c.seats} seats · AutoPay failed';
      case _Kind.free:
        if (e.tier == Tier.legacy) return '$people · early customer';
        return e.trialEnded ? '$people · trial ended' : '$people · Free';
    }
  }

  Widget _pill(CompanyModel c) {
    if (c.status == 'suspended') return const StatusBadge(status: 'suspended');
    return switch (_kindOf(c)) {
      _Kind.trial => const StatusBadge(status: 'pending', label: 'Trial'),
      _Kind.pastDue => const StatusBadge(status: 'absent', label: 'Past due'),
      _Kind.paying =>
        c.plan == 'business'
            ? const StatusBadge(status: 'brand', label: 'Business', dot: false)
            : const StatusBadge(status: 'present', label: 'Pro'),
      _Kind.free => const StatusBadge(status: 'neutral', label: 'Free'),
    };
  }

  void _showSheet(
    BuildContext context,
    CompanyRepository repo,
    CompanyModel company,
  ) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _CompanySheet(repo: repo, company: company),
    );
  }
}

class _CompanySheet extends StatefulWidget {
  const _CompanySheet({required this.repo, required this.company});

  final CompanyRepository repo;
  final CompanyModel company;

  @override
  State<_CompanySheet> createState() => _CompanySheetState();
}

class _CompanySheetState extends State<_CompanySheet> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.company;
    final suspended = c.status == 'suspended';
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xxl,
        0,
        AppSpacing.xxl,
        AppSpacing.xxl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(c.name, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.xl),
          _codeRow(context, 'Employee code', c.employeeCode),
          const SizedBox(height: AppSpacing.md),
          FutureBuilder<({String? code, bool used})>(
            future: widget.repo.getAdminCode(c.id),
            builder: (context, snap) {
              if (!snap.hasData) {
                return _codeRow(context, 'Admin code', '…');
              }
              final data = snap.data!;
              if (data.used) {
                return _infoRow(
                  context,
                  'Admin code',
                  'Claimed by ${c.adminEmail}',
                );
              }
              return _codeRow(context, 'Admin code', data.code ?? '—');
            },
          ),
          const SizedBox(height: AppSpacing.xxl),
          AppButton(
            label: suspended ? 'Reactivate company' : 'Suspend company',
            icon: suspended ? Icons.play_arrow_rounded : Icons.pause_rounded,
            variant: suspended
                ? AppButtonVariant.primary
                : AppButtonVariant.secondary,
            loading: _busy,
            onPressed: _busy
                ? null
                : () async {
                    setState(() => _busy = true);
                    await widget.repo.setStatus(
                      c.id,
                      suspended ? 'active' : 'suspended',
                    );
                    if (context.mounted) Navigator.pop(context);
                  },
          ),
        ],
      ),
    );
  }

  Widget _codeRow(BuildContext context, String label, String code) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(color: colors.textTertiary, fontSize: 12),
                ),
                const SizedBox(height: 2),
                SelectableText(
                  code,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy_rounded, size: 20),
            tooltip: 'Copy',
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: code));
              if (context.mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Code copied')));
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _infoRow(BuildContext context, String label, String value) {
    final colors = context.colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(color: colors.textTertiary, fontSize: 12),
          ),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
