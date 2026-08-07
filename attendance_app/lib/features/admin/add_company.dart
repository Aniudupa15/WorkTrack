import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:attendance_app/core/di/injection.dart';
import 'package:attendance_app/core/error/app_exception.dart';
import 'package:attendance_app/core/theme/app_colors.dart';
import 'package:attendance_app/core/theme/app_spacing.dart';
import 'package:attendance_app/core/widgets/app_button.dart';
import 'package:attendance_app/domain/repositories/company_repository.dart';
import 'package:attendance_app/features/shared/user_provider.dart';

/// Super-admin: provision a company and hand back the admin + employee codes.
class AddCompany extends StatefulWidget {
  const AddCompany({super.key});

  @override
  State<AddCompany> createState() => _AddCompanyState();
}

class _AddCompanyState extends State<AddCompany> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _adminNameCtrl = TextEditingController();
  final _adminEmailCtrl = TextEditingController();
  String _shiftStart = '09:00';
  String _shiftEnd = '18:00';
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _adminNameCtrl.dispose();
    _adminEmailCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickTime(bool isStart) async {
    final current = isStart ? _shiftStart : _shiftEnd;
    final parts = current.split(':');
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      ),
    );
    if (picked != null) {
      final formatted =
          '${picked.hour.toString().padLeft(2, "0")}:${picked.minute.toString().padLeft(2, "0")}';
      setState(() {
        if (isStart) {
          _shiftStart = formatted;
        } else {
          _shiftEnd = formatted;
        }
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final uid = Provider.of<UserProvider>(context, listen: false).user!.id;
      final codes = await sl<CompanyRepository>().createCompany(
        superAdminUid: uid,
        companyName: _nameCtrl.text.trim(),
        address: _addressCtrl.text.trim().isEmpty
            ? null
            : _addressCtrl.text.trim(),
        adminName: _adminNameCtrl.text.trim(),
        adminEmail: _adminEmailCtrl.text.trim(),
        shiftStart: _shiftStart,
        shiftEnd: _shiftEnd,
      );
      if (mounted) {
        await _showCodes(codes.adminCode, codes.employeeCode);
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        final message = e is AppException
            ? e.message
            : 'Could not create the company.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: context.colors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _showCodes(String adminCode, String employeeCode) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Company created'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Share the admin code with the person who’ll run this company. '
              'Employees join with the employee code.',
            ),
            const SizedBox(height: AppSpacing.lg),
            _dialogCode(ctx, 'Admin code (single use)', adminCode),
            const SizedBox(height: AppSpacing.md),
            _dialogCode(ctx, 'Employee code', employeeCode),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Widget _dialogCode(BuildContext context, String label, String code) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Company')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _label('COMPANY'),
              const SizedBox(height: AppSpacing.md),
              _field(
                _nameCtrl,
                'Company name',
                Icons.business_outlined,
                required: true,
              ),
              const SizedBox(height: AppSpacing.md),
              _field(
                _addressCtrl,
                'HQ address (optional)',
                Icons.location_on_outlined,
              ),
              const SizedBox(height: AppSpacing.xxl),
              _label('FIRST ADMIN'),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'This person claims the company with the admin code — PunchIn '
                'assigns the admin role, they don’t pick it.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.md),
              _field(
                _adminNameCtrl,
                'Admin full name',
                Icons.person_outline,
                required: true,
              ),
              const SizedBox(height: AppSpacing.md),
              _field(
                _adminEmailCtrl,
                'Admin work email',
                Icons.alternate_email_rounded,
                required: true,
                keyboard: TextInputType.emailAddress,
              ),
              const SizedBox(height: AppSpacing.xxl),
              _label('DEFAULTS'),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: _timeTile(
                      'Shift start',
                      _shiftStart,
                      () => _pickTime(true),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: _timeTile(
                      'Shift end',
                      _shiftEnd,
                      () => _pickTime(false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xxxl),
              AppButton(
                label: 'Create company & invite admin',
                icon: Icons.check_rounded,
                loading: _saving,
                onPressed: _saving ? null : _submit,
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

  Widget _field(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    bool required = false,
    TextInputType? keyboard,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboard,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
      ),
      validator: required
          ? (v) => v == null || v.trim().isEmpty ? 'Required' : null
          : null,
    );
  }

  Widget _timeTile(String label, String value, VoidCallback onTap) {
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
            Icon(Icons.schedule_rounded, size: 20, color: colors.brand),
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
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
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
