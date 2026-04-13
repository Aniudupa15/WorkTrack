import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import 'work_location_picker.dart';

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
          hour: int.parse(parts[0]), minute: int.parse(parts[1])),
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
              (_workLocation?['radius'] as num?)?.toDouble() ?? widget.defaultRadius,
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
        await DatabaseService()
            .updateEmployee(widget.companyId, widget.employee!.id, {
          'name': _nameCtrl.text.trim(),
          'phone': _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
          'department':
              _deptCtrl.text.trim().isEmpty ? null : _deptCtrl.text.trim(),
          'position':
              _posCtrl.text.trim().isEmpty ? null : _posCtrl.text.trim(),
          'shift': shift,
          'workLocation': _workLocation,
        });
      } else {
        final uid = const Uuid().v4();
        final employee = UserModel(
          id: uid,
          name: _nameCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
          role: 'employee',
          phone:
              _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
          department:
              _deptCtrl.text.trim().isEmpty ? null : _deptCtrl.text.trim(),
          position:
              _posCtrl.text.trim().isEmpty ? null : _posCtrl.text.trim(),
          workLocation: _workLocation,
          shift: shift,
          companyId: widget.companyId,
        );
        try {
          await AuthService().addEmployeeViaFunction(
            companyId: widget.companyId,
            name: employee.name,
            email: employee.email,
            phone: employee.phone,
            department: employee.department,
            position: employee.position,
            workLocation: _workLocation,
            shift: shift,
          );
        } catch (_) {
          // Fallback if Cloud Functions not deployed
          await AuthService().addEmployeeDirectly(widget.companyId, employee);
        }
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: const Color(0xFFDC2626),
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit Employee' : 'Add Employee'),
        backgroundColor: const Color(0xFF1E293B),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(children: [
            _field(_nameCtrl, 'Full Name', Icons.person, required: true),
            const SizedBox(height: 14),
            if (!_isEdit) ...[
              _field(_emailCtrl, 'Email', Icons.email,
                  required: true, keyboard: TextInputType.emailAddress),
              const SizedBox(height: 14),
            ],
            _field(_phoneCtrl, 'Phone (optional)', Icons.phone,
                keyboard: TextInputType.phone),
            const SizedBox(height: 14),
            _field(_deptCtrl, 'Department (optional)', Icons.business),
            const SizedBox(height: 14),
            _field(_posCtrl, 'Position (optional)', Icons.badge),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(
                  child: _timeTile(
                      'Shift Start', _shiftStart, () => _pickShiftTime(true))),
              const SizedBox(width: 12),
              Expanded(
                  child: _timeTile(
                      'Shift End', _shiftEnd, () => _pickShiftTime(false))),
            ]),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: _pickLocation,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withAlpha(25)),
                ),
                child: Row(children: [
                  const Icon(Icons.map, color: Color(0xFF6366F1)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Work Location',
                            style: TextStyle(
                                color: Color(0xFF94A3B8), fontSize: 12)),
                        const SizedBox(height: 4),
                        Text(
                          _workLocation != null
                              ? '${_workLocation!["address"] ?? "Set"} (${(_workLocation!["radius"] as num?)?.round() ?? 100}m)'
                              : 'Tap to set location',
                          style: TextStyle(
                            color: _workLocation != null
                                ? Colors.white
                                : const Color(0xFF94A3B8),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
                ]),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text(_isEdit ? 'Save Changes' : 'Add Employee'),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, IconData icon,
      {bool required = false, TextInputType? keyboard}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboard,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      validator: required
          ? (v) => v == null || v.trim().isEmpty ? 'Required' : null
          : null,
    );
  }

  Widget _timeTile(String label, String value, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withAlpha(25)),
        ),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style:
                      const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
              const SizedBox(height: 4),
              Text(value,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
            ]),
      ),
    );
  }
}
