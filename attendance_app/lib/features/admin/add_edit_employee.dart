import 'package:flutter/material.dart';
import 'package:attendance_app/core/di/injection.dart';
import 'package:attendance_app/core/error/app_exception.dart';
import 'package:attendance_app/core/theme/app_colors.dart';
import 'package:attendance_app/core/theme/app_spacing.dart';
import 'package:attendance_app/core/utils/attendance_clock.dart';
import 'package:attendance_app/core/widgets/app_button.dart';
import 'package:attendance_app/core/widgets/app_card.dart';
import 'package:attendance_app/core/widgets/entity_tile.dart';
import 'package:attendance_app/data/models/location_model.dart';
import 'package:attendance_app/domain/repositories/employee_repository.dart';
import 'package:attendance_app/domain/repositories/location_repository.dart';
import 'package:attendance_app/data/models/user_model.dart';
import 'package:attendance_app/features/admin/assign_sites_sheet.dart';

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
  List<String> _siteIds = [];
  String? _primaryId;
  late final Stream<List<LocationModel>> _sites = sl<LocationRepository>()
      .watchLocations(widget.companyId);
  List<LocationModel> _knownSites = const [];
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
      _siteIds = [...e.locationIds];
      _primaryId = e.primaryLocationId;
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

  Future<void> _chooseSites() async {
    final result = await showAssignSitesSheet(
      context,
      sites: _knownSites,
      selected: _siteIds,
      primaryId: _primaryId,
    );
    if (result != null) {
      setState(() {
        _siteIds = result.ids;
        _primaryId = result.primaryId;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    // HH:mm strings compare chronologically. Overnight shifts aren't supported.
    if (_shiftStart.compareTo(_shiftEnd) >= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Shift end must be after shift start.'),
          backgroundColor: context.colors.danger,
        ),
      );
      return;
    }
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
        shift: {'start': _shiftStart, 'end': _shiftEnd},
      );
      final before = widget.employee!;
      final primary = _knownSites.where((l) => l.id == _primaryId).firstOrNull;
      if (before.primaryLocationId != _primaryId ||
          before.locationIds.join(',') != _siteIds.join(',')) {
        await sl<LocationRepository>().assignLocations(
          widget.companyId,
          before.id,
          locationIds: _siteIds,
          primary: primary,
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
      appBar: AppBar(title: Text(_isEdit ? 'Edit employee' : 'Add employee')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _label('Profile'),
              const SizedBox(height: AppSpacing.md),
              _field(
                _nameCtrl,
                'Full name',
                Icons.person_outline,
                required: true,
              ),
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
              _field(
                _deptCtrl,
                'Department (optional)',
                Icons.business_outlined,
              ),
              const SizedBox(height: AppSpacing.md),
              _field(_posCtrl, 'Position (optional)', Icons.badge_outlined),
              const SizedBox(height: AppSpacing.xxl),
              _label('Shift'),
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
              Row(
                children: [
                  Expanded(child: _label('Work locations')),
                  TextButton(
                    onPressed: _chooseSites,
                    child: Text(_siteIds.isEmpty ? 'Assign' : 'Change'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              StreamBuilder<List<LocationModel>>(
                stream: _sites,
                builder: (context, snap) {
                  _knownSites = snap.data ?? _knownSites;
                  return _sitesCard(colors);
                },
              ),
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
      color: context.colors.textSecondary,
      fontSize: 13,
      fontWeight: FontWeight.w500,
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
                  AttendanceClock.formatShiftTime(value),
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

  Widget _sitesCard(AppColors colors) {
    final byId = {for (final l in _knownSites) l.id: l};
    final assigned = [
      for (final id in _siteIds)
        if (byId[id] != null) byId[id]!,
    ]..sort((a, b) => a.id == _primaryId ? -1 : (b.id == _primaryId ? 1 : 0));
    final legacy = widget.employee?.workLocation;
    if (assigned.isEmpty && _siteIds.isEmpty && legacy?['latitude'] != null) {
      // Pre-v2 single zone that the migration didn't pick up.
      return EntityTile(
        leading: const IconChip(icon: Icons.location_on_outlined),
        title: legacy!['address'] as String? ?? 'Work location',
        subtitle: 'Old single location · assign one to manage it here',
        chevron: true,
        onTap: _chooseSites,
      );
    }
    if (assigned.isEmpty) {
      return EntityTile(
        leading: IconChip(
          icon: Icons.location_off_outlined,
          color: colors.warning,
          background: colors.warningSoft,
        ),
        title: 'No location assigned',
        subtitle: 'They can’t punch in until you assign one',
        chevron: true,
        onTap: _chooseSites,
      );
    }
    return AppGroup(
      children: [
        for (final l in assigned)
          EntityTile(
            inGroup: true,
            leading: IconChip(
              icon: l.id == _primaryId
                  ? Icons.star_rounded
                  : Icons.location_on_outlined,
            ),
            title: l.name,
            subtitle: l.id == _primaryId
                ? 'Primary · ${l.radius.round()} m zone'
                : '${l.radius.round()} m zone',
          ),
      ],
    );
  }
}
