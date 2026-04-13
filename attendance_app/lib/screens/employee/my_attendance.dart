import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../utils/user_provider.dart';
import '../../services/database_service.dart';
import '../../models/attendance_model.dart';

class MyAttendanceScreen extends StatelessWidget {
  const MyAttendanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final prov = Provider.of<UserProvider>(context);
    final companyId = prov.company?.id ?? '';
    final uid = prov.user?.id ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('My Attendance'),
        backgroundColor: const Color(0xFF1E293B),
      ),
      body: StreamBuilder<List<AttendanceModel>>(
        stream: DatabaseService()
            .getEmployeeAttendanceHistory(companyId, uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: Color(0xFF6366F1)));
          }

          final logs = snapshot.data ?? [];

          if (logs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.event_note_rounded,
                      size: 72, color: Colors.grey[800]),
                  const SizedBox(height: 16),
                  Text('No attendance history yet.',
                      style:
                          TextStyle(color: Colors.grey[500], fontSize: 16)),
                ],
              ),
            );
          }

          final now = DateTime.now();
          final currentMonth = DateFormat('yyyy-MM').format(now);
          final monthLogs =
              logs.where((l) => l.date.startsWith(currentMonth)).toList();
          final present = monthLogs
              .where((l) => l.status == 'present' || l.status == 'late')
              .length;
          final late_ = monthLogs.where((l) => l.isLate).length;
          final absent = monthLogs.where((l) => l.status == 'absent').length;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Row(children: [
                  _summaryCard(
                      'Present', '$present', const Color(0xFF10B981)),
                  const SizedBox(width: 10),
                  _summaryCard('Late', '$late_', const Color(0xFFF59E0B)),
                  const SizedBox(width: 10),
                  _summaryCard('Absent', '$absent', const Color(0xFFEF4444)),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                child: Row(children: [
                  const Icon(Icons.history_rounded,
                      size: 16, color: Color(0xFF6366F1)),
                  const SizedBox(width: 10),
                  const Text('RECENT RECORDS',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF94A3B8),
                          letterSpacing: 1.2)),
                ]),
              ),
              Expanded(
                child: ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  itemCount: logs.length,
                  itemBuilder: (context, i) => _logItem(logs[i]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _summaryCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withAlpha(50)),
        ),
        child: Column(children: [
          Text(value,
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(label,
              style:
                  const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
        ]),
      ),
    );
  }

  Widget _logItem(AttendanceModel log) {
    Color statusColor;
    switch (log.status) {
      case 'present':
        statusColor = const Color(0xFF10B981);
        break;
      case 'late':
        statusColor = const Color(0xFFF59E0B);
        break;
      case 'absent':
        statusColor = const Color(0xFFEF4444);
        break;
      default:
        statusColor = const Color(0xFF3B82F6);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withAlpha(12)),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: statusColor.withAlpha(25),
            shape: BoxShape.circle,
          ),
          child: Icon(
            log.status == 'absent'
                ? Icons.person_off
                : log.isLate
                    ? Icons.history_toggle_off_rounded
                    : Icons.how_to_reg_rounded,
            color: statusColor,
            size: 20,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(log.date,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.white)),
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.login_rounded,
                      size: 12, color: Color(0xFF64748B)),
                  const SizedBox(width: 4),
                  Text(
                    log.checkIn != null
                        ? DateFormat('hh:mm a').format(log.checkIn!)
                        : '--:--',
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(width: 16),
                  const Icon(Icons.logout_rounded,
                      size: 12, color: Color(0xFF64748B)),
                  const SizedBox(width: 4),
                  Text(
                    log.checkOut != null
                        ? DateFormat('hh:mm a').format(log.checkOut!)
                        : '--:--',
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF64748B)),
                  ),
                  if (log.workDuration != null) ...[
                    const Spacer(),
                    Text(log.workDurationFormatted,
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF94A3B8))),
                  ],
                ]),
              ]),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor.withAlpha(25),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            log.status.toUpperCase(),
            style: TextStyle(
                color: statusColor,
                fontSize: 10,
                fontWeight: FontWeight.bold),
          ),
        ),
      ]),
    );
  }
}
