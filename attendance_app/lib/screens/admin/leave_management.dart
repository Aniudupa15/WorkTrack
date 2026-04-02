import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/leave_model.dart';
import '../../services/database_service.dart';
import '../../utils/user_provider.dart';

class LeaveManagement extends StatefulWidget {
  const LeaveManagement({super.key});
  @override
  State<LeaveManagement> createState() => _LeaveManagementState();
}

class _LeaveManagementState extends State<LeaveManagement>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final companyId = Provider.of<UserProvider>(context).company?.id ?? '';
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('Leave Management'),
        backgroundColor: const Color(0xFF1E293B),
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: const Color(0xFF6366F1),
          labelColor: Colors.white,
          unselectedLabelColor: const Color(0xFF94A3B8),
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'Approved'),
            Tab(text: 'Rejected'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _LeaveList(companyId: companyId, statusFilter: 'pending'),
          _LeaveList(companyId: companyId, statusFilter: 'approved'),
          _LeaveList(companyId: companyId, statusFilter: 'rejected'),
        ],
      ),
    );
  }
}

class _LeaveList extends StatelessWidget {
  final String companyId;
  final String statusFilter;
  const _LeaveList({required this.companyId, required this.statusFilter});

  @override
  Widget build(BuildContext context) {
    final db = DatabaseService();
    return StreamBuilder<List<LeaveModel>>(
      stream: db.getAllLeaves(companyId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: Color(0xFF6366F1)));
        }
        final all = snap.data ?? [];
        final filtered = all.where((l) => l.status == statusFilter).toList();
        if (filtered.isEmpty) {
          return Center(
            child: Text('No $statusFilter leaves',
                style: const TextStyle(color: Color(0xFF94A3B8))),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filtered.length,
          itemBuilder: (ctx, i) =>
              _LeaveCard(leave: filtered[i], companyId: companyId),
        );
      },
    );
  }
}

class _LeaveCard extends StatelessWidget {
  final LeaveModel leave;
  final String companyId;
  const _LeaveCard({required this.leave, required this.companyId});

  Color get _statusColor {
    switch (leave.status) {
      case 'approved':
        return const Color(0xFF10B981);
      case 'rejected':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFFF59E0B);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy');
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text(leave.employeeName,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _statusColor.withAlpha(30),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(leave.status.toUpperCase(),
                  style: TextStyle(
                      color: _statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold)),
            ),
          ]),
          const SizedBox(height: 8),
          Text(
              '${leave.type.toUpperCase()} - ${dateFormat.format(leave.startDate)} to ${dateFormat.format(leave.endDate)} (${leave.durationDays}d)',
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
          const SizedBox(height: 6),
          Text('Reason: ${leave.reason}',
              style: const TextStyle(color: Colors.white70, fontSize: 13)),
          if (leave.adminNote != null && leave.adminNote!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('Admin note: ${leave.adminNote}',
                style: const TextStyle(
                    color: Color(0xFF6366F1),
                    fontSize: 12,
                    fontStyle: FontStyle.italic)),
          ],
          if (leave.status == 'pending') ...[
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _updateStatus(context, 'rejected'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFEF4444),
                    side: const BorderSide(color: Color(0xFFEF4444)),
                  ),
                  child: const Text('Reject'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _updateStatus(context, 'approved'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                  ),
                  child: const Text('Approve'),
                ),
              ),
            ]),
          ],
        ]),
      ),
    );
  }

  void _updateStatus(BuildContext context, String status) async {
    final noteCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text('${status == "approved" ? "Approve" : "Reject"} Leave',
            style: const TextStyle(color: Colors.white)),
        content: TextField(
          controller: noteCtrl,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Add a note (optional)',
            hintStyle: TextStyle(color: Color(0xFF94A3B8)),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(status == 'approved' ? 'Approve' : 'Reject')),
        ],
      ),
    );
    if (confirmed == true) {
      await DatabaseService().updateLeaveStatus(
        companyId,
        leave.id,
        status,
        noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
      );
    }
  }
}
