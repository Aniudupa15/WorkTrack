import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../services/database_service.dart';
import '../../models/attendance_model.dart';
import '../../utils/color_schema.dart';
import '../../utils/user_provider.dart';

// ── Filter tabs ────────────────────────────────────────────────────────────
enum _Filter { all, onTime, late }

class AttendanceLogsScreen extends StatefulWidget {
  const AttendanceLogsScreen({super.key});

  @override
  State<AttendanceLogsScreen> createState() =>
      _AttendanceLogsScreenState();
}

class _AttendanceLogsScreenState extends State<AttendanceLogsScreen> {
  final DatabaseService _db = DatabaseService();
  final _searchCtrl = TextEditingController();

  DateTime? _selectedDate;
  String    _searchQuery = '';
  _Filter   _filter      = _Filter.all;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Date picker ────────────────────────────────────────────────────────────
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context:     context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate:   DateTime(2020),
      lastDate:    DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary:   AppColors.primaryLight,
            onPrimary: Colors.white,
            surface:   AppColors.bgSurface,
            onSurface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  // ── Filter logic ───────────────────────────────────────────────────────────
  List<AttendanceModel> _applyFilters(List<AttendanceModel> raw) {
    var logs = raw;

    if (_selectedDate != null) {
      final ds = DateFormat('yyyy-MM-dd').format(_selectedDate!);
      logs = logs
          .where((l) =>
      DateFormat('yyyy-MM-dd').format(l.date) == ds)
          .toList();
    }
    if (_searchQuery.isNotEmpty) {
      logs = logs
          .where((l) =>
          l.userId.toLowerCase().contains(_searchQuery))
          .toList();
    }
    if (_filter == _Filter.onTime) {
      logs = logs.where((l) => l.status == 'On-time').toList();
    } else if (_filter == _Filter.late) {
      logs = logs.where((l) => l.status == 'Late').toList();
    }

    return logs;
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final companyId =
        Provider.of<UserProvider>(context, listen: false)
            .user
            ?.companyId ??
            '';

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.bgDark,
        body: StreamBuilder<List<AttendanceModel>>(
          stream: _db.getAllAttendanceLogs(companyId),
          builder: (context, snapshot) {
            final allLogs = snapshot.data ?? [];
            final filtered = _applyFilters(allLogs);

            final total   = allLogs.length;
            final onTime  =
                allLogs.where((l) => l.status == 'On-time').length;
            final late    = total - onTime;

            return Column(
              children: [
                // ── Dark header ──────────────────────────────────────────
                _buildHeader(total, onTime, late),

                // ── Light body ───────────────────────────────────────────
                Expanded(
                  child: Container(
                    decoration: const BoxDecoration(
                      color: AppColors.bgLight,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(28),
                      ),
                    ),
                    child: Column(
                      children: [
                        _buildFilterBar(),
                        Expanded(
                          child: snapshot.connectionState ==
                              ConnectionState.waiting
                              ? const Center(
                            child: CircularProgressIndicator(
                              color: AppColors.primaryLight,
                            ),
                          )
                              : filtered.isEmpty
                              ? _buildEmptyState()
                              : _buildLogList(filtered),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ── Dark header ────────────────────────────────────────────────────────────
  Widget _buildHeader(int total, int onTime, int late) {
    return SafeArea(
      bottom: false,
      child: Stack(
        children: [
          Positioned(
            top: -60, right: -40,
            child: _blob(150, AppColors.primaryLight, 0.10),
          ),
          Positioned(
            bottom: -20, left: -20,
            child: _blob(90, AppColors.primaryGlow, 0.06),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top bar
                Row(
                  children: [
                    // Back
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color:        AppColors.bgSurface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: AppColors.borderDark, width: 1),
                        ),
                        child: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white,
                          size:  15,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    const Text(
                      'Attendance Logs',
                      style: TextStyle(
                        fontSize:   17,
                        fontWeight: FontWeight.w800,
                        color:      Colors.white,
                      ),
                    ),
                    const Spacer(),

                    // Date picker
                    GestureDetector(
                      onTap: _pickDate,
                      child: _headerAction(
                        Icons.calendar_month_rounded,
                        active: _selectedDate != null,
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Reset
                    if (_selectedDate != null)
                      GestureDetector(
                        onTap: () =>
                            setState(() => _selectedDate = null),
                        child: _headerAction(Icons.history_rounded),
                      ),
                  ],
                ),
                const SizedBox(height: 18),

                // Summary pills
                Row(
                  children: [
                    _summaryPill('Total Logs', '$total',
                        Colors.white),
                    const SizedBox(width: 8),
                    _summaryPill('On-time', '$onTime',
                        const Color(0xFF86EFAC)),
                    const SizedBox(width: 8),
                    _summaryPill('Late', '$late',
                        const Color(0xFFFCA5A5)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerAction(IconData icon, {bool active = false}) {
    return Container(
      width: 36, height: 36,
      decoration: BoxDecoration(
        color: active
            ? AppColors.primaryLight.withOpacity(0.2)
            : AppColors.bgSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: active
              ? AppColors.primaryLight
              : AppColors.borderDark,
          width: 1,
        ),
      ),
      child: Icon(icon,
          color: active
              ? AppColors.primaryGlow
              : AppColors.primaryGlow,
          size: 16),
    );
  }

  Widget _summaryPill(String label, String value, Color valueColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color:        AppColors.bgSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderDark, width: 1),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize:   17,
                fontWeight: FontWeight.w800,
                color:      valueColor,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize:   9,
                color:      AppColors.textOnDarkMuted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _blob(double size, Color color, double opacity) =>
      Container(
        width: size, height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withOpacity(opacity),
        ),
      );

  // ── Filter bar ─────────────────────────────────────────────────────────────
  Widget _buildFilterBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        children: [
          // Search
          TextFormField(
            controller: _searchCtrl,
            style: const TextStyle(
              color:      AppColors.textPrimary,
              fontSize:   13.5,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: 'Search by employee ID…',
              hintStyle: const TextStyle(
                  color: AppColors.textMuted, fontSize: 13),
              prefixIcon: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 14),
                child: Icon(Icons.search_rounded,
                    color: AppColors.textMuted, size: 18),
              ),
              prefixIconConstraints:
              const BoxConstraints(minWidth: 46, minHeight: 42),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                icon: const Icon(Icons.close_rounded,
                    color: AppColors.textMuted, size: 16),
                splashRadius: 18,
                onPressed: () {
                  _searchCtrl.clear();
                  setState(() => _searchQuery = '');
                },
              )
                  : null,
              filled:    true,
              fillColor: AppColors.bgWhite,
              contentPadding: const EdgeInsets.symmetric(
                  vertical: 13, horizontal: 16),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                    color: AppColors.border, width: 1.2),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                    color: AppColors.borderStrong, width: 1.6),
              ),
            ),
            onChanged: (v) =>
                setState(() => _searchQuery = v.toLowerCase()),
          ),
          const SizedBox(height: 10),

          // Filter chips row
          Row(
            children: [
              _filterChip('All',     _Filter.all),
              const SizedBox(width: 7),
              _filterChip('On-time', _Filter.onTime),
              const SizedBox(width: 7),
              _filterChip('Late',    _Filter.late),
              const Spacer(),

              // Date chip
              if (_selectedDate != null)
                GestureDetector(
                  onTap: () => setState(() => _selectedDate = null),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color:        AppColors.bgWhite,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: AppColors.border, width: 1.2),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.calendar_today_rounded,
                            color: AppColors.primary, size: 11),
                        const SizedBox(width: 5),
                        Text(
                          DateFormat('MMM d')
                              .format(_selectedDate!),
                          style: const TextStyle(
                            fontSize:   11,
                            fontWeight: FontWeight.w600,
                            color:      AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 5),
                        const Icon(Icons.close_rounded,
                            color: AppColors.textMuted, size: 11),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, _Filter value) {
    final active = _filter == value;
    return GestureDetector(
      onTap: () => setState(() => _filter = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: active
              ? AppColors.primary
              : AppColors.bgWhite,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active
                ? AppColors.primary
                : AppColors.border,
            width: 1.2,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize:   11,
            fontWeight: FontWeight.w700,
            color: active
                ? Colors.white
                : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  // ── Log list ───────────────────────────────────────────────────────────────
  Widget _buildLogList(List<AttendanceModel> logs) {
    return ListView.builder(
      padding:     const EdgeInsets.fromLTRB(16, 4, 16, 20),
      itemCount:   logs.length,
      itemBuilder: (ctx, i) => _LogCard(log: logs[i]),
    );
  }

  // ── Empty state ────────────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64, height: 64,
            decoration: const BoxDecoration(
              color:  AppColors.primaryTint,
              shape:  BoxShape.circle,
            ),
            child: const Icon(
              Icons.event_busy_rounded,
              color: AppColors.primary,
              size:  30,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No records found',
            style: TextStyle(
              fontSize:   15,
              fontWeight: FontWeight.w700,
              color:      AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Try adjusting your filters\nor selecting a different date.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              color:    AppColors.textMuted,
              height:   1.55,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _LogCard — expandable attendance log row
// ─────────────────────────────────────────────────────────────────────────────
class _LogCard extends StatefulWidget {
  final AttendanceModel log;
  const _LogCard({required this.log});

  @override
  State<_LogCard> createState() => _LogCardState();
}

class _LogCardState extends State<_LogCard>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late AnimationController _ctrl;
  late Animation<double>   _expandAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 220),
    );
    _expandAnim = CurvedAnimation(
      parent: _ctrl,
      curve:  Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    _expanded ? _ctrl.forward() : _ctrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final log      = widget.log;
    final isOnTime = log.status == 'On-time';
    final status   = StatusColor.of(
      isOnTime ? AttendanceStatus.present : AttendanceStatus.late,
    );

    // Build avatar initials from userId
    final initials = log.userId.length >= 2
        ? log.userId.substring(0, 2).toUpperCase()
        : 'U';

    final checkIn  = log.checkInTime != null
        ? DateFormat('hh:mm a').format(log.checkInTime!)
        : '--:--';
    final checkOut = log.checkOutTime != null
        ? DateFormat('hh:mm a').format(log.checkOutTime!)
        : 'Not yet';

    // Duration
    String duration = '--';
    if (log.checkInTime != null && log.checkOutTime != null) {
      final diff =
      log.checkOutTime!.difference(log.checkInTime!);
      duration =
      '${diff.inHours}h ${diff.inMinutes.remainder(60)}m';
    }

    final lat = log.location['lat']?.toStringAsFixed(4) ?? '–';
    final lng = log.location['lng']?.toStringAsFixed(4) ?? '–';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color:        AppColors.bgWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: [
          BoxShadow(
            color:      status.fill.withOpacity(0.05),
            blurRadius: 10,
            offset:     const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Collapsed row ──────────────────────────────────────────────
          GestureDetector(
            onTap:     _toggle,
            behavior:  HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  // Avatar
                  Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      color:        status.surface,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Center(
                      child: Text(
                        initials,
                        style: TextStyle(
                          fontSize:   12,
                          fontWeight: FontWeight.w800,
                          color:      status.text,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Name + date
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'User ${log.userId.substring(0, 8)}…',
                          style: const TextStyle(
                            fontSize:   13,
                            fontWeight: FontWeight.w700,
                            color:      AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          DateFormat('MMMM dd, yyyy')
                              .format(log.date),
                          style: const TextStyle(
                            fontSize: 11,
                            color:    AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Status pill
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color:        status.surface,
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Text(
                      log.status.toUpperCase(),
                      style: TextStyle(
                        fontSize:   9.5,
                        fontWeight: FontWeight.w700,
                        color:      status.text,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Chevron
                  AnimatedRotation(
                    turns:    _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 220),
                    child: Container(
                      width: 24, height: 24,
                      decoration: BoxDecoration(
                        color:        AppColors.bgLight,
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: AppColors.textMuted,
                        size:  16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Expanded detail ────────────────────────────────────────────
          SizeTransition(
            sizeFactor: _expandAnim,
            child: Column(
              children: [
                Divider(
                  height: 1,
                  color:  AppColors.border,
                  indent: 14,
                  endIndent: 14,
                ),
                Padding(
                  padding:
                  const EdgeInsets.fromLTRB(14, 12, 14, 14),
                  child: Column(
                    children: [
                      _DetailRow(
                        icon:      Icons.login_rounded,
                        iconColor: AppColors.success,
                        iconBg:    AppColors.successSurface,
                        label:     'Check In',
                        value:     checkIn,
                      ),
                      const SizedBox(height: 9),
                      _DetailRow(
                        icon:      Icons.logout_rounded,
                        iconColor: AppColors.error,
                        iconBg:    AppColors.errorSurface,
                        label:     'Check Out',
                        value:     checkOut,
                      ),
                      const SizedBox(height: 9),
                      _DetailRow(
                        icon:      Icons.timer_outlined,
                        iconColor: AppColors.primary,
                        iconBg:    AppColors.primaryTint,
                        label:     'Duration',
                        value:     duration,
                      ),
                      const SizedBox(height: 9),
                      _DetailRow(
                        icon:      Icons.location_on_rounded,
                        iconColor: AppColors.warning,
                        iconBg:    AppColors.warningSurface,
                        label:     'Location',
                        value:     '$lat, $lng',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _DetailRow
// ─────────────────────────────────────────────────────────────────────────────
class _DetailRow extends StatelessWidget {
  final IconData icon;
  final Color    iconColor, iconBg;
  final String   label, value;

  const _DetailRow({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28, height: 28,
          decoration: BoxDecoration(
            color:        iconBg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: iconColor, size: 13),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(
            fontSize:   12,
            color:      AppColors.textMuted,
            fontWeight: FontWeight.w500,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize:   12.5,
            fontWeight: FontWeight.w700,
            color:      AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}