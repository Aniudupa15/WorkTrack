import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:attendance_app/core/di/injection.dart';
import 'package:attendance_app/core/theme/app_colors.dart';
import 'package:attendance_app/core/theme/app_spacing.dart';
import 'package:attendance_app/core/widgets/app_chip.dart';
import 'package:attendance_app/core/widgets/app_loader.dart';
import 'package:attendance_app/core/widgets/app_search_field.dart';
import 'package:attendance_app/core/widgets/avatar.dart';
import 'package:attendance_app/core/widgets/empty_state.dart';
import 'package:attendance_app/core/widgets/entity_tile.dart';
import 'package:attendance_app/core/widgets/status_badge.dart';
import 'package:attendance_app/data/models/company_model.dart';
import 'package:attendance_app/data/models/user_model.dart';
import 'package:attendance_app/domain/repositories/employee_repository.dart';
import 'package:attendance_app/features/admin/add_edit_employee.dart';
import 'package:attendance_app/features/shared/user_provider.dart';

/// Shows the company code employees use to self-join, with copy + share.
Future<void> _showInviteSheet(
  BuildContext context,
  String companyId,
  String companyName,
) {
  final colors = context.colors;
  final message =
      'Join $companyName on PunchIn.\n\n1. Install PunchIn\n2. Tap "Create Account" → "Join Company"\n3. Enter this company code:\n$companyId';
  return showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (context) => Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        0,
        AppSpacing.xl,
        AppSpacing.xxl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Invite employees',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Share this company code. Employees enter it when creating their account to join $companyName.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.xl),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: colors.surfaceMuted,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: colors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: SelectableText(
                    companyId,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy_rounded),
                  tooltip: 'Copy code',
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: companyId));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Code copied')),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => SharePlus.instance.share(
                ShareParams(
                  text: message,
                  subject: 'Join $companyName on PunchIn',
                ),
              ),
              icon: const Icon(Icons.share_rounded),
              label: const Text('Share invite'),
            ),
          ),
        ],
      ),
    ),
  );
}

class EmployeeManagement extends StatefulWidget {
  const EmployeeManagement({super.key});

  @override
  State<EmployeeManagement> createState() => _EmployeeManagementState();
}

class _EmployeeManagementState extends State<EmployeeManagement> {
  String _query = '';
  String _filter = 'all'; // all | active | inactive

  bool _matches(UserModel e) {
    if (_filter == 'active' && e.status != 'active') return false;
    if (_filter == 'inactive' && e.status == 'active') return false;
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

    return Scaffold(
      appBar: AppBar(title: const Text('Employees')),
      body: StreamBuilder<List<UserModel>>(
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
                  'Share your company code and staff will appear here as they join.',
              action: FilledButton.tonalIcon(
                onPressed: () => _showInviteSheet(
                  context,
                  companyId,
                  prov.company?.name ?? 'us',
                ),
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                label: const Text('Invite employees'),
              ),
            );
          }

          final activeCount = employees
              .where((e) => e.status == 'active')
              .length;
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
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.lg,
                          0,
                          AppSpacing.lg,
                          100,
                        ),
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: AppSpacing.md),
                        itemBuilder: (ctx, i) => _EmployeeCard(
                          employee: filtered[i],
                          companyId: companyId,
                          company: prov.company,
                        ),
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () =>
            _showInviteSheet(context, companyId, prov.company?.name ?? 'us'),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Invite'),
      ),
    );
  }
}

class _EmployeeCard extends StatelessWidget {
  const _EmployeeCard({
    required this.employee,
    required this.companyId,
    this.company,
  });

  final UserModel employee;
  final String companyId;
  final CompanyModel? company;

  @override
  Widget build(BuildContext context) {
    final role = employee.department != null
        ? '${employee.department}${employee.position != null ? " · ${employee.position}" : ""}'
        : employee.email;
    return EntityTile(
      leading: Avatar(name: employee.name, size: 44),
      title: employee.name,
      subtitle: role,
      trailing: StatusBadge(
        status: employee.status == 'active' ? 'present' : 'absent',
        label: employee.status,
      ),
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
