import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:attendance_app/core/di/injection.dart';
import 'package:attendance_app/core/theme/app_colors.dart';
import 'package:attendance_app/core/theme/app_spacing.dart';
import 'package:attendance_app/core/widgets/app_button.dart';
import 'package:attendance_app/core/widgets/app_card.dart';
import 'package:attendance_app/core/widgets/app_loader.dart';
import 'package:attendance_app/core/widgets/app_page.dart';
import 'package:attendance_app/core/widgets/metric_tile.dart';
import 'package:attendance_app/core/widgets/avatar.dart';
import 'package:attendance_app/core/widgets/empty_state.dart';
import 'package:attendance_app/core/widgets/entity_tile.dart';
import 'package:attendance_app/core/widgets/status_badge.dart';
import 'package:attendance_app/data/models/company_model.dart';
import 'package:attendance_app/domain/repositories/company_repository.dart';
import 'package:attendance_app/features/admin/add_company.dart';
import 'package:attendance_app/features/shared/user_provider.dart';

/// Super-admin home: the roster of every company, with the ability to
/// provision new ones and suspend/activate existing ones.
class SuperAdminConsole extends StatelessWidget {
  const SuperAdminConsole({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = sl<CompanyRepository>();
    return Scaffold(
      appBar: TabHeader(
        title: 'Console',
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout_rounded),
            onPressed: () =>
                Provider.of<UserProvider>(context, listen: false).signOut(),
          ),
        ],
      ),
      body: StreamBuilder<List<CompanyModel>>(
        stream: repo.watchCompanies(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const AppLoader();
          }
          final companies = snap.data ?? [];
          final active = companies.where((c) => c.status == 'active').length;
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.xs,
              AppSpacing.lg,
              100,
            ),
            children: [
              MetricRow(
                tiles: [
                  MetricTile(label: 'Companies', value: '${companies.length}'),
                  MetricTile(
                    label: 'Active',
                    value: '$active',
                    dotColor: context.colors.success,
                  ),
                  MetricTile(
                    label: 'Suspended',
                    value: '${companies.length - active}',
                    dotColor: context.colors.danger,
                  ),
                ],
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
                    for (final c in companies)
                      EntityTile(
                        inGroup: true,
                        leading: Avatar(name: c.name, square: true),
                        title: c.name,
                        subtitle:
                            '${c.totalEmployees} people · ${c.hasAdmin ? c.adminEmail : "admin not claimed"}',
                        trailing: StatusBadge(status: c.status),
                        onTap: () => _showSheet(context, repo, c),
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
