import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/leave_model.dart';
import '../../services/database_service.dart';
import '../../utils/user_provider.dart';
import 'leave_request.dart';

class MyLeaves extends StatelessWidget {
  const MyLeaves({super.key});

  @override
  Widget build(BuildContext context) {
    final prov = Provider.of<UserProvider>(context);
    final companyId = prov.company?.id ?? '';
    final uid = prov.user?.id ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('My Leaves'),
        backgroundColor: const Color(0xFF1E293B),
      ),
      body: StreamBuilder<List<LeaveModel>>(
        stream: DatabaseService().getEmployeeLeaves(companyId, uid),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: Color(0xFF6366F1)));
          }
          final leaves = snap.data ?? [];
          if (leaves.isEmpty) {
            return const Center(
              child: Text('No leave requests yet',
                  style: TextStyle(color: Color(0xFF94A3B8))),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: leaves.length,
            itemBuilder: (ctx, i) => _LeaveCard(leave: leaves[i]),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => const LeaveRequest())),
        backgroundColor: const Color(0xFF6366F1),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

class _LeaveCard extends StatelessWidget {
  final LeaveModel leave;
  const _LeaveCard({required this.leave});

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

  IconData get _statusIcon {
    switch (leave.status) {
      case 'approved':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      default:
        return Icons.hourglass_empty;
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
            Icon(_statusIcon, color: _statusColor, size: 20),
            const SizedBox(width: 8),
            Text(leave.type.toUpperCase(),
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15)),
            const Spacer(),
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
          const SizedBox(height: 10),
          Text(
            '${dateFormat.format(leave.startDate)} - ${dateFormat.format(leave.endDate)}  (${leave.durationDays}d)',
            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
          ),
          const SizedBox(height: 6),
          Text(leave.reason,
              style: const TextStyle(color: Colors.white70, fontSize: 13)),
          if (leave.adminNote != null && leave.adminNote!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(children: [
                const Icon(Icons.comment, size: 14, color: Color(0xFF6366F1)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Admin: ${leave.adminNote}',
                      style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 12,
                          fontStyle: FontStyle.italic)),
                ),
              ]),
            ),
          ],
        ]),
      ),
    );
  }
}
