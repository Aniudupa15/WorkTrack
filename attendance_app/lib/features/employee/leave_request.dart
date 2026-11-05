import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:attendance_app/core/di/injection.dart';
import 'package:attendance_app/core/error/app_exception.dart';
import 'package:attendance_app/core/theme/app_colors.dart';
import 'package:attendance_app/core/theme/app_spacing.dart';
import 'package:attendance_app/core/widgets/app_button.dart';
import 'package:attendance_app/core/widgets/app_chip.dart';
import 'package:attendance_app/data/datasources/analytics_service.dart';
import 'package:attendance_app/data/models/leave_model.dart';
import 'package:attendance_app/domain/repositories/leave_repository.dart';
import 'package:attendance_app/core/utils/attendance_clock.dart';
import 'package:attendance_app/features/shared/leave_balance.dart';
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
  String _dayPart = 'full';
  late final Stream<List<LeaveModel>> _mine = () {
    final prov = Provider.of<UserProvider>(context, listen: false);
    return sl<LeaveRepository>().watchEmployeeLeaves(
      prov.company?.id ?? '',
      prov.user?.id ?? '',
    );
  }();

  bool get _singleDay => DateUtils.isSameDay(_startDate, _endDate);

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
        if (!_singleDay) _dayPart = 'full';
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
        dayPart: _singleDay ? _dayPart : 'full',
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
    return StreamBuilder<List<LeaveModel>>(
      stream: _mine,
      builder: (context, snap) => _build(context, snap.data ?? const []),
    );
  }

  Widget _build(BuildContext context, List<LeaveModel> mine) {
    final colors = context.colors;
    final prov = Provider.of<UserProvider>(context);
    final company = prov.company;
    final workingDays = company?.workingDays ?? const [1, 2, 3, 4, 5, 6];
    final year = AttendanceClock.now().year;
    double left(String t) =>
        (leaveQuota(company, t) ?? 0) -
        leaveUsed(mine, t, year, workingDays, pending: true);
    final dateFormat = DateFormat('EEE, d MMM');
    final days = leaveDays(
      _startDate,
      _endDate,
      workingDays: workingDays,
      dayPart: _singleDay ? _dayPart : 'full',
    );
    final quota = leaveQuota(company, _type);
    final after = quota == null ? null : left(_type) - days;
    final approver = (company?.adminName ?? '').trim();

    return Scaffold(
      appBar: AppBar(title: const Text('Request time off')),
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
              _label('Leave type'),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: _leaveTypes
                    .map(
                      (t) => AppChip(
                        label: leaveQuota(company, t) == null
                            ? '${t[0].toUpperCase()}${t.substring(1)}'
                            : '${t[0].toUpperCase()}${t.substring(1)} · '
                                  '${fmtDays(left(t).clamp(0, 999).toDouble())}',
                        selected: _type == t,
                        onTap: () => setState(() => _type = t),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: AppSpacing.xxl),
              _label('Dates'),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: _dateTile(
                      'From',
                      dateFormat.format(_startDate),
                      () => _pickDate(true),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: _dateTile(
                      'To',
                      dateFormat.format(_endDate),
                      () => _pickDate(false),
                    ),
                  ),
                ],
              ),
              if (_singleDay) ...[
                const SizedBox(height: AppSpacing.md),
                AppSegmented<String>(
                  segments: const {
                    'full': 'Full day',
                    'first_half': 'First half',
                    'second_half': 'Second half',
                  },
                  selected: _dayPart,
                  onChanged: (v) => setState(() => _dayPart = v),
                ),
              ],
              const SizedBox(height: AppSpacing.xxl),
              _label('Reason'),
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
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: colors.surfaceMuted,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        days == 0
                            ? 'No working days picked'
                            : '${fmtDays(days)} working '
                                  '${days == 1 ? 'day' : 'days'}',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    if (after != null)
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: after < 0
                                  ? '${fmtDays(-after)} over'
                                  : '${fmtDays(after)} $_type '
                                        '${after == 1 ? 'day' : 'days'}',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: after < 0 ? colors.danger : null,
                              ),
                            ),
                            TextSpan(
                              text: after < 0
                                  ? ' your allowance'
                                  : ' left after this',
                            ),
                          ],
                        ),
                        style: const TextStyle(fontSize: 13),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                label: 'Send request',
                loading: _submitting,
                onPressed: _submitting || days == 0 ? null : _submit,
              ),
              const SizedBox(height: AppSpacing.sm),
              Center(
                child: Text(
                  approver.isEmpty
                      ? 'Goes to your manager for approval'
                      : 'Goes to $approver for approval',
                  style: TextStyle(fontSize: 12, color: colors.textTertiary),
                ),
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
      color: context.colors.textSecondary,
      fontSize: 13,
      fontWeight: FontWeight.w500,
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
          borderRadius: BorderRadius.circular(AppRadius.md),
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
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
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
