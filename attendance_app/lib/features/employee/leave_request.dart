import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:attendance_app/core/di/injection.dart';
import 'package:attendance_app/core/error/app_exception.dart';
import 'package:attendance_app/core/theme/app_colors.dart';
import 'package:attendance_app/core/theme/app_spacing.dart';
import 'package:attendance_app/core/widgets/app_button.dart';
import 'package:attendance_app/core/widgets/app_card.dart';
import 'package:attendance_app/core/widgets/app_chip.dart';
import 'package:attendance_app/data/datasources/analytics_service.dart';
import 'package:attendance_app/data/models/leave_model.dart';
import 'package:attendance_app/domain/repositories/leave_repository.dart';
import 'package:attendance_app/features/shared/user_provider.dart';

class LeaveRequest extends StatefulWidget {
  const LeaveRequest({super.key});

  @override
  State<LeaveRequest> createState() => _LeaveRequestState();
}

class _LeaveRequestState extends State<LeaveRequest> {
  final _formKey = GlobalKey<FormState>();
  final _reasonCtrl = TextEditingController();
  String _type = 'casual';
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  bool _submitting = false;

  final _leaveTypes = ['casual', 'sick', 'earned', 'other'];

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime.now().subtract(const Duration(days: 7)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_endDate.isBefore(_startDate)) _endDate = _startDate;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_endDate.isBefore(_startDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End date cannot be before start date')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final prov = Provider.of<UserProvider>(context, listen: false);
      final leave = LeaveModel(
        id: '',
        employeeId: prov.user!.id,
        companyId: prov.company!.id,
        employeeName: prov.user!.name,
        type: _type,
        startDate: _startDate,
        endDate: _endDate,
        reason: _reasonCtrl.text.trim(),
        createdAt: DateTime.now(),
      );
      await sl<LeaveRepository>().submitLeave(prov.company!.id, leave);
      unawaited(sl<AnalyticsService>().logLeaveRequested(_type));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Leave request submitted'),
            backgroundColor: context.colors.success,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        final message = e is AppException ? e.message : 'Something went wrong';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: context.colors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final dateFormat = DateFormat('dd MMM yyyy');
    final days = _endDate.difference(_startDate).inDays + 1;

    return Scaffold(
      appBar: AppBar(title: const Text('Request Leave')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.md,
          AppSpacing.xl,
          40,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _label('LEAVE TYPE'),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: _leaveTypes
                    .map(
                      (t) => AppChip(
                        label: '${t[0].toUpperCase()}${t.substring(1)}',
                        selected: _type == t,
                        onTap: () => setState(() => _type = t),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: AppSpacing.xxl),
              _label('DURATION'),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: _dateTile(
                      'Start',
                      dateFormat.format(_startDate),
                      () => _pickDate(true),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: _dateTile(
                      'End',
                      dateFormat.format(_endDate),
                      () => _pickDate(false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xxl),
              _label('REASON'),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _reasonCtrl,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Briefly describe why you need this time off',
                  alignLabelWithHint: true,
                ),
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Please enter a reason'
                    : null,
              ),
              const SizedBox(height: AppSpacing.xxl),
              // Summary before submit
              AppCard(
                color: colors.brandSoft,
                border: false,
                child: Row(
                  children: [
                    Icon(
                      Icons.event_available_rounded,
                      color: colors.brand,
                      size: 22,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        'You’re requesting $days ${days > 1 ? "days" : "day"} '
                        'of $_type leave.',
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                label: 'Submit request',
                icon: Icons.send_rounded,
                loading: _submitting,
                onPressed: _submitting ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
    text,
    style: TextStyle(
      color: context.colors.textTertiary,
      fontSize: 12,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.4,
    ),
  );

  Widget _dateTile(String label, String value, VoidCallback onTap) {
    final colors = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today_rounded,
              size: 18,
              color: colors.textSecondary,
            ),
            const SizedBox(width: AppSpacing.md),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(color: colors.textTertiary, fontSize: 12),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
