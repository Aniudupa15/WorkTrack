import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../utils/user_provider.dart';
import '../../services/database_service.dart';
import 'add_edit_employee.dart';

class EmployeeManagement extends StatelessWidget {
  const EmployeeManagement({super.key});

  @override
  Widget build(BuildContext context) {
    final prov = Provider.of<UserProvider>(context);
    final companyId = prov.company?.id ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('Employees'),
        backgroundColor: const Color(0xFF1E293B),
      ),
      body: StreamBuilder<List<UserModel>>(
        stream: DatabaseService().getAllEmployees(companyId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: Color(0xFF6366F1)));
          }
          final employees = snap.data ?? [];
          if (employees.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.people_outline, size: 64, color: Colors.grey[700]),
                  const SizedBox(height: 16),
                  Text('No employees yet',
                      style: TextStyle(color: Colors.grey[500], fontSize: 16)),
                  const SizedBox(height: 8),
                  Text('Tap + to add your first employee',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: employees.length,
            itemBuilder: (ctx, i) => _EmployeeCard(
              employee: employees[i],
              companyId: companyId,
              company: prov.company,
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
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
        backgroundColor: const Color(0xFF6366F1),
        child: const Icon(Icons.person_add, color: Colors.white),
      ),
    );
  }
}

class _EmployeeCard extends StatelessWidget {
  final UserModel employee;
  final String companyId;
  final dynamic company;

  const _EmployeeCard({
    required this.employee,
    required this.companyId,
    this.company,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
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
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            CircleAvatar(
              backgroundColor: const Color(0xFF6366F1).withAlpha(30),
              radius: 24,
              child: Text(
                employee.name.isNotEmpty ? employee.name[0].toUpperCase() : '?',
                style: const TextStyle(
                    color: Color(0xFF6366F1),
                    fontWeight: FontWeight.bold,
                    fontSize: 18),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(employee.name,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15)),
                  const SizedBox(height: 4),
                  Text(employee.email,
                      style:
                          const TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                  if (employee.department != null) ...[
                    const SizedBox(height: 2),
                    Text(
                        '${employee.department}${employee.position != null ? " - ${employee.position}" : ""}',
                        style: const TextStyle(
                            color: Color(0xFF64748B), fontSize: 12)),
                  ],
                ],
              ),
            ),
            Column(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: employee.status == 'active'
                        ? const Color(0xFF10B981).withAlpha(25)
                        : const Color(0xFFEF4444).withAlpha(25),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    employee.status.toUpperCase(),
                    style: TextStyle(
                      color: employee.status == 'active'
                          ? const Color(0xFF10B981)
                          : const Color(0xFFEF4444),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text('${employee.shiftStart} - ${employee.shiftEnd}',
                    style: const TextStyle(
                        color: Color(0xFF64748B), fontSize: 11)),
              ],
            ),
          ]),
        ),
      ),
    );
  }
}
