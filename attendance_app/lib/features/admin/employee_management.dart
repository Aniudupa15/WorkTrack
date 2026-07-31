import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
              subtitle: 'Tap + to add your first employee.',
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
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AddEditEmployee(
              companyId: companyId,
              defaultRadius: prov.company?.defaultRadius ?? 100,
              defaultShiftStart: prov.company?.defaultShiftStart ?? '09:00',
              defaultShiftEnd: prov.company?.defaultShiftEnd ?? '18:00',
            ),
          ),
        ),
        icon: const Icon(Icons.person_add),
        label: const Text('Add'),
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
