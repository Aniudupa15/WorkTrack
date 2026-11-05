import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:attendance_app/core/di/injection.dart';
import 'package:attendance_app/core/error/app_exception.dart';
import 'package:attendance_app/core/theme/app_colors.dart';
import 'package:attendance_app/core/theme/app_spacing.dart';
import 'package:attendance_app/core/utils/attendance_clock.dart';
import 'package:attendance_app/core/widgets/app_button.dart';
import 'package:attendance_app/core/widgets/app_card.dart';
import 'package:attendance_app/core/widgets/entity_tile.dart';
import 'package:attendance_app/core/widgets/status_badge.dart';
import 'package:attendance_app/domain/repositories/company_repository.dart';
import 'package:attendance_app/features/shared/leave_balance.dart';
import 'package:attendance_app/features/shared/user_provider.dart';

/// Yearly leave allowance per type and the company's holiday list. Holidays
/// never count as absent, and leave days skip them.
class LeaveRulesScreen extends StatefulWidget {
  const LeaveRulesScreen({super.key});

  @override
  State<LeaveRulesScreen> createState() => _LeaveRulesScreenState();
}

class _LeaveRulesScreenState extends State<LeaveRulesScreen> {
  late final Map<String, int> _quota;
  late final List<({String date, String name})> _holidays;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final c = Provider.of<UserProvider>(context, listen: false).company;
    _quota = {for (final t in quotaLeaveTypes) t: leaveQuota(c, t)!};
    _holidays = [...holidaysOf(c)];
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _addHoliday() async {
    final now = AttendanceClock.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2, 12, 31),
    );
    if (date == null || !mounted) return;
    final nameCtrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(DateFormat('EEE, d MMM yyyy').format(date)),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'e.g. Diwali'),
          onSubmitted: (v) => Navigator.pop(d, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(d, nameCtrl.text),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    nameCtrl.dispose();
    if (name == null || name.trim().isEmpty) return;
    final key = DateFormat('yyyy-MM-dd').format(date);
    setState(() {
      _holidays
        ..removeWhere((h) => h.date == key)
        ..add((date: key, name: name.trim()))
        ..sort((a, b) => a.date.compareTo(b.date));
    });
  }

  Future<void> _save() async {
    final prov = Provider.of<UserProvider>(context, listen: false);
    final company = prov.company;
    if (company == null) return;
    setState(() => _busy = true);
    try {
      await sl<CompanyRepository>().updateSettings(company.id, {
        ...company.settings,
        'leaveQuota': _quota,
        'holidays': [
          for (final h in _holidays) {'date': h.date, 'name': h.name},
        ],
      });
      await prov.refreshUser();
      if (!mounted) return;
      _snack('Saved');
      Navigator.pop(context);
    } catch (e) {
      _snack(e is AppException ? e.message : 'Couldn’t save');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final today = AttendanceClock.today();
    final upcoming = _holidays.where((h) => h.date.compareTo(today) >= 0);
    final past = _holidays.where((h) => h.date.compareTo(today) < 0);

    Widget section(String t) => Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
      child: Text(
        t.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.6,
          color: colors.textTertiary,
        ),
      ),
    );

    Widget holiday(({String date, String name}) h) => EntityTile(
      inGroup: true,
      title: h.name,
      subtitle: DateFormat('EEE, d MMM yyyy').format(DateTime.parse(h.date)),
      trailing: IconButton(
        tooltip: 'Remove',
        icon: Icon(Icons.close_rounded, color: colors.textTertiary),
        onPressed: () => setState(() => _holidays.remove(h)),
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Leave & holidays')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          section('Leave per year'),
          AppGroup(
            children: [
              for (final t in quotaLeaveTypes)
                EntityTile(
                  inGroup: true,
                  title: StatusBadge.humanise(t),
                  subtitle: '${_quota[t]} days a year',
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Fewer',
                        icon: const Icon(Icons.remove_rounded),
                        onPressed: _quota[t]! <= 0
                            ? null
                            : () => setState(() => _quota[t] = _quota[t]! - 1),
                      ),
                      SizedBox(
                        width: 28,
                        child: Text(
                          '${_quota[t]}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'More',
                        icon: const Icon(Icons.add_rounded),
                        onPressed: _quota[t]! >= 60
                            ? null
                            : () => setState(() => _quota[t] = _quota[t]! + 1),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'People see what’s left on their Leaves tab. Requests over the '
            'allowance still come to you — you decide.',
            style: TextStyle(fontSize: 12, color: colors.textTertiary),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(child: section('Holidays')),
              TextButton.icon(
                onPressed: _addHoliday,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add'),
              ),
            ],
          ),
          if (_holidays.isEmpty)
            AppCard(
              child: Text(
                'No holidays yet. Add the days your company is closed — '
                'nobody is marked absent on them.',
                style: TextStyle(color: colors.textSecondary),
              ),
            )
          else ...[
            if (upcoming.isNotEmpty)
              AppGroup(children: [for (final h in upcoming) holiday(h)]),
            if (past.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              section('Past'),
              AppGroup(children: [for (final h in past) holiday(h)]),
            ],
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: AppButton(
            label: 'Save',
            loading: _busy,
            onPressed: _busy ? null : _save,
          ),
        ),
      ),
    );
  }
}
