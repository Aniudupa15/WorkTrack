import 'package:flutter/material.dart';
import '../../services/database_service.dart';
import '../../models/attendance_model.dart';
import 'package:provider/provider.dart';
import '../../utils/user_provider.dart';
import 'package:intl/intl.dart';

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
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('Attendance Logs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month_rounded),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate ?? DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
                builder: (context, child) {
                  return Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: const ColorScheme.dark(
                        primary: Color(0xFF6366F1),
                        onPrimary: Colors.white,
                        surface: Color(0xFF1E293B),
                        onSurface: Colors.white,
                      ),
                    ),
                    child: child!,
                  );
                },
              );
              if (picked != null) setState(() => _selectedDate = picked);
            },
          ),
          if (_selectedDate != null)
            IconButton(
              icon: const Icon(Icons.history_rounded),
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
              decoration: InputDecoration(
                hintText: 'Search by employee ID...',
                prefixIcon: const Icon(Icons.search_rounded),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                suffixIcon: _searchQuery.isNotEmpty 
                    ? IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _searchQuery = ''))
                    : null,
              ),
            ),
          ),
          if (_selectedDate != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Chip(
                label: Text(DateFormat('MMMM dd, yyyy').format(_selectedDate!)),
                onDeleted: () => setState(() => _selectedDate = null),
                backgroundColor: const Color(0xFF6366F1).withOpacity(0.1),
                labelStyle: const TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.bold),
                deleteIconColor: const Color(0xFF6366F1),
              ),
            ),
          Expanded(
            child: StreamBuilder<List<AttendanceModel>>(
              stream: _db.getAllAttendanceLogs(
                Provider.of<UserProvider>(context, listen: false).user?.companyId ?? '',
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)));
                }

                var logs = snapshot.data ?? [];

                // Filter by date
                if (_selectedDate != null) {
                  final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate!);
                  logs = logs.where((log) => DateFormat('yyyy-MM-dd').format(log.date) == dateStr).toList();
                }

                // Filter by search query
                if (_searchQuery.isNotEmpty) {
                  logs = logs.where((log) => 
                    log.userId.toLowerCase().contains(_searchQuery)
                  ).toList();
                }

                if (logs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.event_busy_rounded, size: 64, color: Colors.grey[800]),
                        const SizedBox(height: 16),
                        Text('No records found', style: TextStyle(color: Colors.grey[500], fontSize: 16)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: logs.length,
                  itemBuilder: (context, index) {
                    final log = logs[index];
                    return _buildLogCard(log);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogCard(AttendanceModel log) {
    bool onTime = log.status == 'On-time';
    Color statusColor = onTime ? const Color(0xFF10B981) : const Color(0xFFF59E0B);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          shape: const RoundedRectangleBorder(side: BorderSide.none),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              onTime ? Icons.how_to_reg_rounded : Icons.history_toggle_off_rounded,
              color: statusColor,
              size: 24,
            ),
          ),
          title: Text(
            'User ${log.userId.substring(0, 8)}...',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          subtitle: Text(
            DateFormat('MMMM dd, yyyy').format(log.date),
            style: TextStyle(color: Colors.grey[500], fontSize: 12),
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              log.status.toUpperCase(),
              style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                children: [
                  const Divider(color: Colors.white10),
                  const SizedBox(height: 12),
                  _buildDetailRow(Icons.login_rounded, 'Check In', 
                      log.checkInTime != null ? DateFormat('hh:mm a').format(log.checkInTime!) : '--:--'),
                  const SizedBox(height: 12),
                  _buildDetailRow(Icons.logout_rounded, 'Check Out', 
                      log.checkOutTime != null ? DateFormat('hh:mm a').format(log.checkOutTime!) : '--:--'),
                  const SizedBox(height: 12),
                  _buildDetailRow(Icons.location_on_rounded, 'Position', 
                      '${log.location['lat']!.toStringAsFixed(4)}, ${log.location['lng']!.toStringAsFixed(4)}'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 13)),
        const Spacer(),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.white70)),
      ],
    );
  }
}
