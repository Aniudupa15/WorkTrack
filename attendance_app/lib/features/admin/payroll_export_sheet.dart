import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:attendance_app/core/billing/entitlements.dart';
import 'package:attendance_app/core/di/injection.dart';
import 'package:attendance_app/core/theme/app_colors.dart';
import 'package:attendance_app/core/theme/app_spacing.dart';
import 'package:attendance_app/core/widgets/app_button.dart';
import 'package:attendance_app/data/datasources/report_service.dart';
import 'package:attendance_app/data/models/attendance_model.dart';
import 'package:attendance_app/domain/repositories/employee_repository.dart';
import 'package:attendance_app/domain/repositories/leave_repository.dart';
import 'package:attendance_app/features/billing/paywall.dart';
import 'package:attendance_app/features/shared/user_provider.dart';

/// Business plan: export [month] for payroll in the chosen tool's layout.
Future<void> showPayrollExport(
  BuildContext context, {
  required DateTime month,
  required List<AttendanceModel> records,
}) {
  final company = Provider.of<UserProvider>(context, listen: false).company;
  if (!Entitlements.of(company).hasBusiness) {
    return showPaywall(context, PaywallReason.payroll);
  }
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _PayrollSheet(month: month, records: records),
  );
}

class _PayrollSheet extends StatefulWidget {
  const _PayrollSheet({required this.month, required this.records});

  final DateTime month;
  final List<AttendanceModel> records;

  @override
  State<_PayrollSheet> createState() => _PayrollSheetState();
}

class _PayrollSheetState extends State<_PayrollSheet> {
  PayrollFormat _format = PayrollFormat.summary;
  bool _busy = false;

  Future<void> _export() async {
    final company = Provider.of<UserProvider>(context, listen: false).company!;
    setState(() => _busy = true);
    try {
      final employees = await sl<EmployeeRepository>().getEmployeesOnce(
        company.id,
      );
      final leaves = await sl<LeaveRepository>()
          .watchAllLeaves(company.id)
          .first;
      await sl<ReportService>().sharePayrollCsv(
        companyName: company.name,
        month: widget.month,
        format: _format,
        // Everyone on the books this month, including people since deactivated.
        employees: employees.where((e) => e.status != 'pending').toList(),
        records: widget.records,
        leaves: leaves,
      );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Couldn’t build the payroll export')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = context.colors;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          0,
          AppSpacing.xl,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Payroll export', style: text.titleLarge),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${DateFormat('MMMM yyyy').format(widget.month)} · days present, '
              'late marks, absences, approved leave and hours.',
              style: text.bodySmall,
            ),
            const SizedBox(height: AppSpacing.md),
            RadioGroup<PayrollFormat>(
              groupValue: _format,
              onChanged: (f) => setState(() => _format = f!),
              child: Column(
                children: [
                  for (final f in PayrollFormat.values)
                    RadioListTile<PayrollFormat>(
                      value: f,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        f.label,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(f.description),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'People are matched by email, or phone when there’s no email. '
              'Check the columns against your payroll tool’s import template '
              'the first time.',
              style: text.labelSmall?.copyWith(color: colors.textTertiary),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: 'Export CSV',
              icon: Icons.ios_share_rounded,
              loading: _busy,
              onPressed: _busy ? null : _export,
            ),
          ],
        ),
      ),
    );
  }
}
