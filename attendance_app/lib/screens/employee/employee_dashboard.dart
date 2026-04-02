import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../utils/user_provider.dart';
import '../../services/database_service.dart';
import '../../models/attendance_model.dart';
import 'mark_attendance.dart';
import 'my_attendance.dart';
import 'my_leaves.dart';

class EmployeeDashboard extends StatelessWidget {
  const EmployeeDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final db = DatabaseService();

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('My Workspace'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Color(0xFFF87171)),
            onPressed: () => userProvider.signOut(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProfileHeader(userProvider),
            const SizedBox(height: 32),
            _buildTodayStatus(db, userProvider),
            const SizedBox(height: 40),
            _buildSectionHeader('Quick Actions', Icons.bolt_rounded),
            const SizedBox(height: 16),
            _buildActionCard(
              context,
              'Mark Attendance',
              'Check-in or Check-out for today',
              Icons.location_on_rounded,
              const Color(0xFF6366F1),
              const MarkAttendanceScreen(),
            ),
            const SizedBox(height: 16),
            _buildActionCard(
              context,
              'Attendance History',
              'View your past check-in records',
              Icons.history_rounded,
              const Color(0xFF818CF8),
              const MyAttendanceScreen(),
            ),
            const SizedBox(height: 16),
            _buildActionCard(
              context,
              'My Leaves',
              'Request and track leave applications',
              Icons.event_busy_rounded,
              const Color(0xFFF59E0B),
              const MyLeaves(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(UserProvider provider) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF6366F1), const Color(0xFF4F46E5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const CircleAvatar(
              radius: 32,
              backgroundColor: Colors.white,
              child: Icon(Icons.person_rounded, size: 40, color: Color(0xFF6366F1)),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hello, ${provider.user?.name.split(' ')[0]} 👋',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                Text(
                  provider.user?.email ?? '',
                  style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Shift: ${provider.user?.shiftStart} - ${provider.user?.shiftEnd}',
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayStatus(DatabaseService db, UserProvider userProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader("Today's Journey", Icons.today_rounded),
        const SizedBox(height: 16),
        FutureBuilder<AttendanceModel?>(
          future: db.getTodayAttendance(
              userProvider.company?.id ?? '', userProvider.user?.id ?? ''),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)));
            }

            final attendance = snapshot.data;
            final isCheckedIn = attendance != null;
            final isCheckedOut = attendance?.checkOut != null;

            return Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: Row(
                children: [
                  _buildStatusItem('Check In', isCheckedIn, attendance?.checkIn, const Color(0xFF10B981)),
                  Expanded(
                    child: Container(
                      height: 2,
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            isCheckedIn ? const Color(0xFF10B981) : Colors.grey[800]!,
                            isCheckedOut ? const Color(0xFF10B981) : Colors.grey[800]!,
                          ],
                        ),
                      ),
                    ),
                  ),
                  _buildStatusItem('Check Out', isCheckedOut, attendance?.checkOut, const Color(0xFFF43F5E)),
                ],
              ),
            );
          },
        ),
      ],
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

  Widget _buildStatusItem(String label, bool active, DateTime? time, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: active ? color.withOpacity(0.1) : Colors.white.withOpacity(0.05),
            shape: BoxShape.circle,
          ),
          child: Icon(
            active ? Icons.check_circle_rounded : Icons.radio_button_off_rounded,
            color: active ? color : Colors.grey[600],
            size: 28,
          ),
        ),
        const SizedBox(height: 12),
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        Text(
          time != null ? DateFormat('hh:mm a').format(time) : '--:--',
          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
        ),
      ],
    );
  }

  Widget _buildActionCard(BuildContext context, String title, String subtitle, IconData icon, Color color, Widget screen) {
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
            const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Color(0xFF475569)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIndicator(String label, bool completed, DateTime? time) {
    return Column(
      children: [
        Icon(
          completed ? Icons.check_circle : Icons.radio_button_unchecked,
          color: completed ? Colors.green : Colors.grey,
          size: 32,
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        Text(
          time != null ? DateFormat('HH:mm').format(time) : '--:--',
          style: TextStyle(color: Colors.grey[600]),
        ),
      ],
    );
  }
}
