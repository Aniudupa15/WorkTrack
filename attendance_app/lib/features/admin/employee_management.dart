import 'package:flutter/material.dart';

import 'package:attendance_app/core/billing/entitlements.dart';
import 'package:attendance_app/features/billing/paywall.dart';
import 'package:provider/provider.dart';

import 'package:attendance_app/core/di/injection.dart';
import 'package:attendance_app/core/theme/app_colors.dart';
import 'package:attendance_app/core/theme/app_spacing.dart';
import 'package:attendance_app/core/widgets/app_button.dart';
import 'package:attendance_app/core/widgets/app_card.dart';
import 'package:attendance_app/core/widgets/app_chip.dart';
import 'package:attendance_app/core/widgets/app_page.dart';
import 'package:attendance_app/core/widgets/app_loader.dart';
import 'package:attendance_app/core/widgets/app_search_field.dart';
import 'package:attendance_app/core/widgets/avatar.dart';
import 'package:attendance_app/core/widgets/empty_state.dart';
import 'package:attendance_app/core/widgets/entity_tile.dart';
import 'package:attendance_app/core/widgets/status_badge.dart';
import 'package:attendance_app/data/models/company_model.dart';
import 'package:attendance_app/data/models/location_model.dart';
import 'package:attendance_app/data/models/user_model.dart';
import 'package:attendance_app/domain/repositories/employee_repository.dart';
import 'package:attendance_app/domain/repositories/location_repository.dart';
import 'package:attendance_app/features/admin/add_edit_employee.dart';
import 'package:attendance_app/features/admin/invite_screen.dart';
import 'package:attendance_app/features/shared/user_provider.dart';

class EmployeeManagement extends StatefulWidget {
  const EmployeeManagement({super.key});

  @override
  State<EmployeeManagement> createState() => _EmployeeManagementState();
}

class _EmployeeManagementState extends State<EmployeeManagement> {
  String _query = '';
  String _filter = 'all'; // all | active | inactive
  String? _site; // location id, or null for every location
  Stream<List<LocationModel>>? _sites;

  bool _matches(UserModel e) {
    if (_filter == 'active' && e.status != 'active') return false;
    if (_filter == 'inactive' && e.status == 'active') return false;
    if (_site != null && !e.locationIds.contains(_site)) return false;
    if (_query.isEmpty) return true;
    final q = _query.toLowerCase();
    return e.name.toLowerCase().contains(q) ||
        e.email.toLowerCase().contains(q) ||
        (e.department?.toLowerCase().contains(q) ?? false) ||
        (e.position?.toLowerCase().contains(q) ?? false);
  }

  @override
  Widget build(BuildContext context) {
    final prov = Provider.of<UserProvider>(context);
    final companyId = prov.company?.id ?? '';
    _sites ??= sl<LocationRepository>().watchLocations(companyId);

    return StreamBuilder<List<LocationModel>>(
      stream: _sites,
      builder: (context, siteSnap) =>
          _build(context, prov, companyId, siteSnap.data ?? const []),
    );
  }

  Widget _build(
    BuildContext context,
    UserProvider prov,
    String companyId,
    List<LocationModel> sites,
  ) {
    return Scaffold(
      appBar: TabHeader(
        title: 'Team',
        actions: [
          AppButton(
            label: 'Add',
            size: AppButtonSize.small,
            expand: false,
            onPressed: () => _openInvite(context),
          ),
        ],
      ),
      body: Column(
        children: [
          _PendingJoiners(companyId: companyId),
          Expanded(child: _directory(context, prov, companyId, sites)),
        ],
      ),
    );
  }

  void _openInvite(BuildContext context) {
    final company = Provider.of<UserProvider>(context, listen: false).company;
    if (!Entitlements.of(company).canAddPeople(company?.activeEmployees ?? 0)) {
      showPaywall(context, PaywallReason.morePeople);
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const InviteScreen()),
    );
  }

  Widget _directory(
    BuildContext context,
    UserProvider prov,
    String companyId,
    List<LocationModel> sites,
  ) {
    final siteNames = {for (final s in sites) s.id: s.name};
    return StreamBuilder<List<UserModel>>(
      stream: sl<EmployeeRepository>().watchEmployees(companyId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const AppLoader();
        }
        final employees = snap.data ?? [];
        if (employees.isEmpty) {
          return EmptyState(
            icon: Icons.people_outline,
            title: 'No employees yet',
            subtitle:
                'Invite people by phone or share your company code. They '
                'appear here as they join.',
            action: FilledButton.tonalIcon(
              onPressed: () => _openInvite(context),
              icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
              label: const Text('Invite employees'),
            ),
          );
        }

        final activeCount = employees.where((e) => e.status == 'active').length;
        final filtered = employees.where(_matches).toList();

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppSearchField(
                    hint: 'Search name, email, or role',
                    onChanged: (v) => setState(() => _query = v),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppChipBar(
                    children: [
                      AppChip(
                        label: 'All',
                        count: employees.length,
                        selected: _filter == 'all',
                        onTap: () => setState(() => _filter = 'all'),
                      ),
                      AppChip(
                        label: 'Active',
                        count: activeCount,
                        selected: _filter == 'active',
                        onTap: () => setState(() => _filter = 'active'),
                      ),
                      AppChip(
                        label: 'Inactive',
                        count: employees.length - activeCount,
                        selected: _filter == 'inactive',
                        onTap: () => setState(() => _filter = 'inactive'),
                      ),
                    ],
                  ),
                  if (sites.length > 1) ...[
                    const SizedBox(height: AppSpacing.sm),
                    AppChipBar(
                      children: [
                        AppChip(
                          label: 'All locations',
                          icon: Icons.location_on_outlined,
                          selected: _site == null,
                          onTap: () => setState(() => _site = null),
                        ),
                        for (final s in sites)
                          AppChip(
                            label: s.name,
                            selected: _site == s.id,
                            onTap: () => setState(() => _site = s.id),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? const EmptyState(
                      icon: Icons.search_off_rounded,
                      title: 'No matches',
                      subtitle: 'Try a different name, role, or filter.',
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        0,
                        AppSpacing.lg,
                        AppSpacing.xxl,
                      ),
                      children: [
                        AppGroup(
                          children: [
                            for (final e in filtered)
                              _EmployeeCard(
                                employee: e,
                                companyId: companyId,
                                company: prov.company,
                                siteNames: siteNames,
                              ),
                          ],
                        ),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _EmployeeCard extends StatelessWidget {
  const _EmployeeCard({
    required this.employee,
    required this.companyId,
    this.company,
    this.siteNames = const {},
  });

  final UserModel employee;
  final String companyId;
  final CompanyModel? company;
  final Map<String, String> siteNames;

  /// "Head office", "Head office +2", or the legacy address.
  String? get _siteLabel {
    final ids = employee.locationIds;
    if (ids.isEmpty) {
      return employee.workAddress ??
          (employee.workLatitude == null ? 'No location assigned' : null);
    }
    final primary =
        siteNames[employee.primaryLocationId ?? ids.first] ??
        siteNames[ids.first];
    if (primary == null) return null;
    return ids.length > 1 ? '$primary +${ids.length - 1}' : primary;
  }

  @override
  Widget build(BuildContext context) {
    final parts = [
      _siteLabel,
      employee.department,
    ].whereType<String>().where((s) => s.isNotEmpty);
    return EntityTile(
      inGroup: true,
      leading: Avatar(name: employee.name, imageUrl: employee.avatarUrl),
      title: employee.name,
      subtitle: parts.isEmpty ? employee.email : parts.join(' · '),
      trailing: StatusBadge(status: employee.status),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AddEditEmployee(
            employee: employee,
            companyId: companyId,
            defaultRadius: company?.defaultRadius ?? 100,
            defaultShiftStart: company?.defaultShiftStart ?? '09:00',
            defaultShiftEnd: company?.defaultShiftEnd ?? '18:00',
          ),
        ),
      ),
    );
  }
}

/// People who joined with the company code while "Approve new joiners" is on.
class _PendingJoiners extends StatelessWidget {
  const _PendingJoiners({required this.companyId});

  final String companyId;

  @override
  Widget build(BuildContext context) {
    final repo = sl<EmployeeRepository>();
    return StreamBuilder<List<UserModel>>(
      stream: repo.watchPendingEmployees(companyId),
      builder: (context, snap) {
        final pending = snap.data ?? const <UserModel>[];
        if (pending.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Waiting for approval (${pending.length})',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              AppGroup(
                children: [
                  for (final e in pending)
                    EntityTile(
                      inGroup: true,
                      leading: Avatar(name: e.name),
                      title: e.name,
                      subtitle: e.phone ?? e.email,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton(
                            onPressed: () =>
                                repo.setStatus(companyId, e.id, 'inactive'),
                            child: Text(
                              'Decline',
                              style: TextStyle(color: context.colors.danger),
                            ),
                          ),
                          AppButton(
                            label: 'Approve',
                            size: AppButtonSize.small,
                            expand: false,
                            onPressed: () =>
                                repo.setStatus(companyId, e.id, 'active'),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
