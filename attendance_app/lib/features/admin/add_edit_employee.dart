import 'package:flutter/material.dart';
import 'package:attendance_app/core/di/injection.dart';
import 'package:attendance_app/core/error/app_exception.dart';
import 'package:attendance_app/core/theme/app_colors.dart';
import 'package:attendance_app/core/theme/app_spacing.dart';
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
      final shift = {'start': _shiftStart, 'end': _shiftEnd};

      if (_isEdit) {
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
          shift: shift,
        );
      } else {
        await sl<EmployeeRepository>().addEmployee(
          companyId: widget.companyId,
          name: _nameCtrl.text,
          email: _emailCtrl.text,
          phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
          department: _deptCtrl.text.trim().isEmpty
              ? null
              : _deptCtrl.text.trim(),
          position: _posCtrl.text.trim().isEmpty ? null : _posCtrl.text.trim(),
          workLocation: _workLocation,
          shift: shift,
        );
      }
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
            children: [
              _field(_nameCtrl, 'Full Name', Icons.person, required: true),
              const SizedBox(height: 14),
              if (!_isEdit) ...[
                _field(
                  _emailCtrl,
                  'Email',
                  Icons.email,
                  required: true,
                  keyboard: TextInputType.emailAddress,
                ),
                const SizedBox(height: 14),
              ],
              _field(
                _phoneCtrl,
                'Phone (optional)',
                Icons.phone,
                keyboard: TextInputType.phone,
              ),
              const SizedBox(height: 14),
              _field(_deptCtrl, 'Department (optional)', Icons.business),
              const SizedBox(height: 14),
              _field(_posCtrl, 'Position (optional)', Icons.badge),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _timeTile(
                      'Shift Start',
                      _shiftStart,
                      () => _pickShiftTime(true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _timeTile(
                      'Shift End',
                      _shiftEnd,
                      () => _pickShiftTime(false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: _pickLocation,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(color: colors.border),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.map, color: colors.brand),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Work Location',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              _workLocation != null
                                  ? '${_workLocation!["address"] ?? "Set"} (${(_workLocation!["radius"] as num?)?.round() ?? 100}m)'
                                  : 'Tap to set location',
                              style: TextStyle(
                                color: _workLocation != null
                                    ? colors.textPrimary
                                    : colors.textSecondary,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, color: colors.textTertiary),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colors.onBrand,
                        ),
                      )
                    : Text(_isEdit ? 'Save Changes' : 'Add Employee'),
              ),
            ],
          ),
        ),
      ),
    );
  }

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
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: AppSpacing.xs),
            Text(
              value,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
