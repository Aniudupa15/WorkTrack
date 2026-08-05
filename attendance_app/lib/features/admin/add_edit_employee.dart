import 'package:flutter/material.dart';
import 'package:attendance_app/core/di/injection.dart';
import 'package:attendance_app/core/error/app_exception.dart';
import 'package:attendance_app/core/theme/app_colors.dart';
import 'package:attendance_app/core/theme/app_spacing.dart';
import 'package:attendance_app/core/widgets/app_button.dart';
import 'package:attendance_app/domain/repositories/employee_repository.dart';
import 'package:attendance_app/data/models/user_model.dart';
import 'package:attendance_app/features/admin/work_location_picker.dart';

class AddEditEmployee extends StatefulWidget {
  final UserModel? employee;
  final String companyId;
  final double defaultRadius;
  final String defaultShiftStart;
  final String defaultShiftEnd;

  const AddEditEmployee({
    super.key,
    this.employee,
    required this.companyId,
    this.defaultRadius = 100,
    this.defaultShiftStart = '09:00',
    this.defaultShiftEnd = '18:00',
  });

  @override
  State<AddEditEmployee> createState() => _AddEditEmployeeState();
}

class _AddEditEmployeeState extends State<AddEditEmployee> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _deptCtrl = TextEditingController();
  final _posCtrl = TextEditingController();
  String _shiftStart = '09:00';
  String _shiftEnd = '18:00';
  Map<String, dynamic>? _workLocation;
  bool _saving = false;

  bool get _isEdit => widget.employee != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      final e = widget.employee!;
      _nameCtrl.text = e.name;
      _emailCtrl.text = e.email;
      _phoneCtrl.text = e.phone ?? '';
      _deptCtrl.text = e.department ?? '';
      _posCtrl.text = e.position ?? '';
      _shiftStart = e.shiftStart;
      _shiftEnd = e.shiftEnd;
      _workLocation = e.workLocation;
    } else {
      _shiftStart = widget.defaultShiftStart;
      _shiftEnd = widget.defaultShiftEnd;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _deptCtrl.dispose();
    _posCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickShiftTime(bool isStart) async {
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

  Future<void> _pickLocation() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => WorkLocationPicker(
          initialLat: _workLocation?['latitude'] as double?,
          initialLng: _workLocation?['longitude'] as double?,
          initialRadius:
              (_workLocation?['radius'] as num?)?.toDouble() ??
              widget.defaultRadius,
        ),
      ),
    );
    if (result != null) setState(() => _workLocation = result);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      await sl<EmployeeRepository>().updateEmployee(
        companyId: widget.companyId,
        employeeId: widget.employee!.id,
        name: _nameCtrl.text,
        phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        department: _deptCtrl.text.trim().isEmpty
            ? null
            : _deptCtrl.text.trim(),
        position: _posCtrl.text.trim().isEmpty ? null : _posCtrl.text.trim(),
        workLocation: _workLocation,
        shift: {'start': _shiftStart, 'end': _shiftEnd},
      );
      if (mounted) Navigator.pop(context, true);
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
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit Employee' : 'Add Employee')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _label('PROFILE'),
              const SizedBox(height: AppSpacing.md),
              _field(_nameCtrl, 'Full name', Icons.person_outline, required: true),
              const SizedBox(height: AppSpacing.md),
              if (!_isEdit) ...[
                _field(
                  _emailCtrl,
                  'Email',
                  Icons.alternate_email_rounded,
                  required: true,
                  keyboard: TextInputType.emailAddress,
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              _field(
                _phoneCtrl,
                'Phone (optional)',
                Icons.phone_outlined,
                keyboard: TextInputType.phone,
              ),
              const SizedBox(height: AppSpacing.md),
              _field(_deptCtrl, 'Department (optional)', Icons.business_outlined),
              const SizedBox(height: AppSpacing.md),
              _field(_posCtrl, 'Position (optional)', Icons.badge_outlined),
              const SizedBox(height: AppSpacing.xxl),
              _label('SCHEDULE'),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: _timeTile(
                      'Shift start',
                      _shiftStart,
                      () => _pickShiftTime(true),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: _timeTile(
                      'Shift end',
                      _shiftEnd,
                      () => _pickShiftTime(false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xxl),
              _label('WORK LOCATION'),
              const SizedBox(height: AppSpacing.md),
              _locationCard(colors),
              const SizedBox(height: AppSpacing.xxxl),
              AppButton(
                label: _isEdit ? 'Save changes' : 'Add employee',
                icon: Icons.check_rounded,
                loading: _saving,
                onPressed: _saving ? null : _save,
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

  Widget _locationCard(AppColors colors) {
    final isSet = _workLocation != null;
    final accent = isSet ? colors.success : colors.brand;
    return GestureDetector(
      onTap: _pickLocation,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: isSet ? accent.withValues(alpha: 0.08) : colors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: isSet ? accent.withValues(alpha: 0.4) : colors.border,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(
                isSet ? Icons.where_to_vote_rounded : Icons.map_outlined,
                color: accent,
                size: 20,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isSet ? 'Location set' : 'No location set',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isSet
                        ? '${_workLocation!["address"] ?? "Custom point"} · ${(_workLocation!["radius"] as num?)?.round() ?? 100}m radius'
                        : 'Tap to place the geofence on the map',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: colors.textTertiary, fontSize: 13),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: colors.textTertiary),
          ],
        ),
      ),
    );
  }
}
