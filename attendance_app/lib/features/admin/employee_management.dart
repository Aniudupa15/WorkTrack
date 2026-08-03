import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:attendance_app/core/di/injection.dart';
import 'package:attendance_app/core/theme/app_colors.dart';
import 'package:attendance_app/core/theme/app_spacing.dart';
import 'package:attendance_app/core/widgets/app_loader.dart';
import 'package:attendance_app/core/widgets/empty_state.dart';
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

class EmployeeManagement extends StatelessWidget {
  const EmployeeManagement({super.key});

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
            return const EmptyState(
              icon: Icons.people_outline,
              title: 'No employees yet',
              subtitle: 'Tap Invite to share your company code.',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: employees.length,
            itemBuilder: (ctx, i) => _EmployeeCard(
              employee: employees[i],
              companyId: companyId,
              company: prov.company,
            ),
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
    final colors = context.colors;
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.xl),
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
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: colors.brandSoft,
                radius: 24,
                child: Text(
                  employee.name.isNotEmpty
                      ? employee.name[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                    color: colors.brand,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      employee.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      employee.email,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    if (employee.department != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        '${employee.department}${employee.position != null ? " - ${employee.position}" : ""}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                children: [
                  StatusBadge(
                    status: employee.status == 'active' ? 'present' : 'absent',
                    label: employee.status,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    '${employee.shiftStart} - ${employee.shiftEnd}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
