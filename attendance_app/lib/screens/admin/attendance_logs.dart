import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../services/database_service.dart';
import '../../models/attendance_model.dart';
import '../../utils/user_provider.dart';

class AttendanceLogsScreen extends StatefulWidget {
  const AttendanceLogsScreen({super.key});
  @override
  State<AttendanceLogsScreen> createState() => _AttendanceLogsScreenState();
}

class _AttendanceLogsScreenState extends State<AttendanceLogsScreen> {
  final DatabaseService _db = DatabaseService();
  DateTime? _selectedDate;
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final companyId =
        Provider.of<UserProvider>(context, listen: false).company?.id ?? '';
    final dateFilter = _selectedDate != null
        ? DateFormat('yyyy-MM-dd').format(_selectedDate!)
        : null;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('Attendance Logs'),
        backgroundColor: const Color(0xFF1E293B),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month_rounded),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate ?? DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
                builder: (context, child) => Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: const ColorScheme.dark(
                      primary: Color(0xFF6366F1),
                      onPrimary: Colors.white,
                      surface: Color(0xFF1E293B),
                      onSurface: Colors.white,
                    ),
                  ),
                  child: child!,
                ),
              );
              if (picked != null) setState(() => _selectedDate = picked);
            },
          ),
          if (_selectedDate != null)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () => setState(() => _selectedDate = null),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search by employee name...',
                prefixIcon: const Icon(Icons.search_rounded),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(() => _searchQuery = ''))
                    : null,
              ),
            ),
          ),
          if (_selectedDate != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Chip(
                label: Text(DateFormat('MMMM dd, yyyy').format(_selectedDate!)),
                onDeleted: () => setState(() => _selectedDate = null),
                backgroundColor: const Color(0xFF6366F1).withAlpha(25),
                labelStyle: const TextStyle(
                    color: Color(0xFF6366F1), fontWeight: FontWeight.bold),
                deleteIconColor: const Color(0xFF6366F1),
              ),
            ),
          Expanded(
            child: StreamBuilder<List<AttendanceModel>>(
              stream:
                  _db.getAllAttendanceLogs(companyId, dateFilter: dateFilter),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(
                          color: Color(0xFF6366F1)));
                }
                var logs = snapshot.data ?? [];

                if (_searchQuery.isNotEmpty) {
                  logs = logs
                      .where((log) =>
                          log.employeeName
                              .toLowerCase()
                              .contains(_searchQuery) ||
                          log.employeeId
                              .toLowerCase()
                              .contains(_searchQuery))
                      .toList();
                }

                if (logs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.event_busy_rounded,
                            size: 64, color: Colors.grey[800]),
                        const SizedBox(height: 16),
                        Text('No records found',
                            style: TextStyle(
                                color: Colors.grey[500], fontSize: 16)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: logs.length,
                  itemBuilder: (context, index) =>
                      _buildLogCard(logs[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogCard(AttendanceModel log) {
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
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withAlpha(12)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          shape: const RoundedRectangleBorder(side: BorderSide.none),
          leading: Container(
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
              size: 22,
            ),
          ),
          title: Text(
            log.employeeName.isNotEmpty
                ? log.employeeName
                : log.employeeId.substring(0, 8),
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
          ),
          subtitle: Text(log.date,
              style: TextStyle(color: Colors.grey[500], fontSize: 12)),
          trailing: Container(
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
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(children: [
                const Divider(color: Colors.white10),
                const SizedBox(height: 12),
                _row(Icons.login_rounded, 'Check In',
                    log.checkIn != null ? DateFormat('hh:mm a').format(log.checkIn!) : '--:--'),
                const SizedBox(height: 10),
                _row(Icons.logout_rounded, 'Check Out',
                    log.checkOut != null ? DateFormat('hh:mm a').format(log.checkOut!) : '--:--'),
                const SizedBox(height: 10),
                _row(Icons.timelapse, 'Duration', log.workDurationFormatted),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(IconData icon, String label, String value) {
    return Row(children: [
      Icon(icon, size: 16, color: Colors.grey[600]),
      const SizedBox(width: 12),
      Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 13)),
      const Spacer(),
      Text(value,
          style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: Colors.white70)),
    ]);
  }
}
