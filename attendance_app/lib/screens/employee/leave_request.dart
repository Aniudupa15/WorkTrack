import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/leave_model.dart';
import '../../services/database_service.dart';
import '../../utils/user_provider.dart';

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
      await DatabaseService().submitLeave(prov.company!.id, leave);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Leave request submitted'),
              backgroundColor: Color(0xFF10B981)),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'),
              backgroundColor: const Color(0xFFEF4444)),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy');
    final days = _endDate.difference(_startDate).inDays + 1;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('Request Leave'),
        backgroundColor: const Color(0xFF1E293B),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Leave Type',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: _leaveTypes
                      .map((t) => ChoiceChip(
                            label: Text(t.toUpperCase()),
                            selected: _type == t,
                            onSelected: (_) => setState(() => _type = t),
                            selectedColor: const Color(0xFF6366F1),
                            labelStyle: TextStyle(
                                color:
                                    _type == t ? Colors.white : const Color(0xFF94A3B8),
                                fontSize: 12,
                                fontWeight: FontWeight.bold),
                            backgroundColor: const Color(0xFF1E293B),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 20),
                Row(children: [
                  Expanded(
                    child: _dateTile(
                        'Start Date', dateFormat.format(_startDate), () => _pickDate(true)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _dateTile(
                        'End Date', dateFormat.format(_endDate), () => _pickDate(false)),
                  ),
                ]),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text('$days day${days > 1 ? "s" : ""}',
                      style: const TextStyle(
                          color: Color(0xFF6366F1), fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _reasonCtrl,
                  maxLines: 4,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Reason',
                    alignLabelWithHint: true,
                    prefixIcon: Icon(Icons.notes),
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Please enter a reason' : null,
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Submit Request'),
                ),
              ]),
        ),
      ),
    );
  }

  Widget _dateTile(String label, String value, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withAlpha(25)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold)),
        ]),
      ),
    );
  }
}
