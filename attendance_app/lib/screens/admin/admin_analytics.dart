import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/attendance_model.dart';
import '../../services/database_service.dart';
import '../../utils/user_provider.dart';

class AdminAnalytics extends StatefulWidget {
  const AdminAnalytics({super.key});
  @override
  State<AdminAnalytics> createState() => _AdminAnalyticsState();
}

class _AdminAnalyticsState extends State<AdminAnalytics> {
  final _db = DatabaseService();
  DateTime _selectedMonth = DateTime.now();
  List<AttendanceModel> _records = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final companyId =
        Provider.of<UserProvider>(context, listen: false).company?.id ?? '';
    final ym = DateFormat('yyyy-MM').format(_selectedMonth);
    _records = await _db.getAttendanceForMonth(companyId, ym);
    setState(() => _loading = false);
  }

  void _changeMonth(int delta) {
    setState(() {
      _selectedMonth =
          DateTime(_selectedMonth.year, _selectedMonth.month + delta);
    });
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final present = _records.where((r) => r.status == 'present').length;
    final late = _records.where((r) => r.status == 'late').length;
    final absent = _records.where((r) => r.status == 'absent').length;
    final halfDay = _records.where((r) => r.status == 'half_day').length;
    final total = _records.length;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('Analytics'),
        backgroundColor: const Color(0xFF1E293B),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF6366F1)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                // Month selector
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                        onPressed: () => _changeMonth(-1),
                        icon: const Icon(Icons.chevron_left,
                            color: Colors.white)),
                    Text(DateFormat('MMMM yyyy').format(_selectedMonth),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                    IconButton(
                        onPressed: () => _changeMonth(1),
                        icon: const Icon(Icons.chevron_right,
                            color: Colors.white)),
                  ],
                ),
                const SizedBox(height: 20),

                // Summary cards
                Row(children: [
                  _statCard('Present', present, const Color(0xFF10B981)),
                  const SizedBox(width: 8),
                  _statCard('Late', late, const Color(0xFFF59E0B)),
                  const SizedBox(width: 8),
                  _statCard('Absent', absent, const Color(0xFFEF4444)),
                  const SizedBox(width: 8),
                  _statCard('Half Day', halfDay, const Color(0xFF3B82F6)),
                ]),
                const SizedBox(height: 24),

                // Pie chart
                if (total > 0) ...[
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Attendance Distribution',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 200,
                    child: PieChart(PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 40,
                      sections: [
                        if (present > 0)
                          PieChartSectionData(
                              value: present.toDouble(),
                              title: '$present',
                              color: const Color(0xFF10B981),
                              radius: 50,
                              titleStyle: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold)),
                        if (late > 0)
                          PieChartSectionData(
                              value: late.toDouble(),
                              title: '$late',
                              color: const Color(0xFFF59E0B),
                              radius: 50,
                              titleStyle: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold)),
                        if (absent > 0)
                          PieChartSectionData(
                              value: absent.toDouble(),
                              title: '$absent',
                              color: const Color(0xFFEF4444),
                              radius: 50,
                              titleStyle: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold)),
                        if (halfDay > 0)
                          PieChartSectionData(
                              value: halfDay.toDouble(),
                              title: '$halfDay',
                              color: const Color(0xFF3B82F6),
                              radius: 50,
                              titleStyle: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold)),
                      ],
                    )),
                  ),
                  const SizedBox(height: 20),
                  // Legend
                  Wrap(spacing: 16, runSpacing: 8, children: [
                    _legend('Present', const Color(0xFF10B981)),
                    _legend('Late', const Color(0xFFF59E0B)),
                    _legend('Absent', const Color(0xFFEF4444)),
                    _legend('Half Day', const Color(0xFF3B82F6)),
                  ]),
                ] else
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: Text('No data for this month',
                          style: TextStyle(color: Color(0xFF94A3B8))),
                    ),
                  ),
              ]),
            ),
    );
  }

  Widget _statCard(String label, int count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withAlpha(50)),
        ),
        child: Column(children: [
          Text('$count',
              style: TextStyle(
                  color: color, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
        ]),
      ),
    );
  }

  Widget _legend(String label, Color color) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 6),
      Text(label, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
    ]);
  }
}
