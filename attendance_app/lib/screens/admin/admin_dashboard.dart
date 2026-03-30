import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../utils/user_provider.dart';
import '../../services/database_service.dart';
import '../../models/attendance_model.dart';
import '../../models/user_model.dart';
import 'employee_management.dart';
import 'attendance_logs.dart';
import 'package:intl/intl.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final db = DatabaseService();

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(userProvider.company?.name ?? 'Admin Dashboard',
                style: const TextStyle(fontSize: 18, color: Colors.white)),
            Text('Workspace Overview',
                style: TextStyle(fontSize: 12, color: Colors.grey[400])),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.logout_rounded, color: Color(0xFFF87171)),
              onPressed: () => userProvider.signOut(),
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<UserModel>>(
        stream: db.getAllEmployees(userProvider.user?.companyId ?? ''),
        builder: (context, employeesSnapshot) {
          return StreamBuilder<List<AttendanceModel>>(
            stream: db.getAllAttendanceLogs(userProvider.user?.companyId ?? ''),
            builder: (context, attendanceSnapshot) {
              if (employeesSnapshot.connectionState == ConnectionState.waiting ||
                  attendanceSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)));
              }

              final employees = employeesSnapshot.data ?? [];
              final allLogs = attendanceSnapshot.data ?? [];
              final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
              final todayLogs = allLogs
                  .where((log) => DateFormat('yyyy-MM-dd').format(log.date) == today)
                  .toList();

              int totalEmployees = employees.length;
              int presentToday = todayLogs.length;
              int absentToday = totalEmployees - presentToday;
              int lateCheckins = todayLogs.where((log) => log.status == 'Late').length;

              return SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome back, ${userProvider.user?.name.split(' ')[0]} 👋',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 24),
                    _buildStatsGrid(totalEmployees, presentToday, absentToday, lateCheckins),
                    const SizedBox(height: 40),
                    _buildSectionHeader('Management', Icons.settings_suggest_rounded),
                    const SizedBox(height: 16),
                    _buildActionButton(
                      context,
                      'Employee Directory',
                      'Add, edit or remove staff accounts',
                      Icons.people_alt_rounded,
                      const Color(0xFF818CF8),
                      const EmployeeManagement(),
                    ),
                    const SizedBox(height: 16),
                    _buildActionButton(
                      context,
                      'Attendance History',
                      'Detailed logs and check-in reports',
                      Icons.history_edu_rounded,
                      const Color(0xFFFB7185),
                      const AttendanceLogsScreen(),
                    ),
                    const SizedBox(height: 40),
                    _buildSectionHeader('Recent Activity', Icons.bolt_rounded),
                    const SizedBox(height: 16),
                    _buildRecentActivityList(todayLogs),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFF6366F1)),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
      ],
    );
  }

  Widget _buildStatsGrid(int total, int present, int absent, int late) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.4,
      children: [
        _buildStatCard('Fleet Size', '$total', const Color(0xFF6366F1), Icons.group_rounded),
        _buildStatCard('Checked In', '$present', const Color(0xFF10B981), Icons.how_to_reg_rounded),
        _buildStatCard('On Leave', '$absent', const Color(0xFFF43F5E), Icons.person_off_rounded),
        _buildStatCard('Delayed', '$late', const Color(0xFFF59E0B), Icons.alarm_on_rounded),
      ],
    );
  }

  Widget _buildActionButton(BuildContext context, String title, String subtitle, IconData icon, Color color, Widget screen) {
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => screen)),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(color: Colors.grey[400], fontSize: 13)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF475569)),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivityList(List<AttendanceModel> logs) {
    if (logs.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.inbox_rounded, size: 48, color: Colors.grey[700]),
                const SizedBox(height: 16),
                Text('No check-ins today yet', style: TextStyle(color: Colors.grey[500])),
              ],
            ),
          ),
        ),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: logs.length > 5 ? 5 : logs.length,
      itemBuilder: (context, index) {
        final log = logs[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: log.status == 'On-time' ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                radius: 18,
                child: Icon(
                  log.status == 'On-time' ? Icons.check_rounded : Icons.access_time_rounded,
                  size: 16,
                  color: log.status == 'On-time' ? Colors.green : Colors.orange,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('User ${log.userId.substring(0, 5)}...', style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text(DateFormat('hh:mm a').format(log.checkInTime!), style: TextStyle(fontSize: 12, color: Colors.grey[400])),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: log.status == 'On-time' ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  log.status,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: log.status == 'On-time' ? Colors.green : Colors.orange,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value, Color color, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 28),
            const Spacer(),
            Text(title, style: TextStyle(fontSize: 12, color: Colors.grey[400])),
            Text(
              value,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
