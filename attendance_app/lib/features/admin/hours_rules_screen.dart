import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:attendance_app/core/di/injection.dart';
import 'package:attendance_app/core/error/app_exception.dart';
import 'package:attendance_app/core/theme/app_colors.dart';
import 'package:attendance_app/core/theme/app_spacing.dart';
import 'package:attendance_app/core/utils/attendance_clock.dart';
import 'package:attendance_app/core/widgets/app_button.dart';
import 'package:attendance_app/core/widgets/app_card.dart';
import 'package:attendance_app/core/widgets/app_chip.dart';
import 'package:attendance_app/domain/repositories/company_repository.dart';
import 'package:attendance_app/features/onboarding/onboarding_step.dart';
import 'package:attendance_app/features/shared/user_provider.dart';

/// Company-wide hours and attendance rules (the setup's step 5, editable
/// later): default shift, working days, late grace and the policy toggles.
class HoursRulesScreen extends StatefulWidget {
  const HoursRulesScreen({super.key});

  @override
  State<HoursRulesScreen> createState() => _HoursRulesScreenState();
}

class _HoursRulesScreenState extends State<HoursRulesScreen> {
  static const _lateOptions = [5, 10, 15, 30];
  late String _start;
  late String _end;
  late Set<int> _days;
  late int _lateAfter;
  late bool _checkoutInZone;
  late bool _reminders;
  late bool _selfie;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final c = Provider.of<UserProvider>(context, listen: false).company;
    _start = c?.defaultShiftStart ?? '09:00';
    _end = c?.defaultShiftEnd ?? '18:00';
    _days = {...?c?.workingDays};
    if (_days.isEmpty) _days = {1, 2, 3, 4, 5, 6};
    final late = c?.lateAfterMinutes ?? 15;
    _lateAfter = _lateOptions.contains(late) ? late : 15;
    _checkoutInZone = c?.checkoutInZone ?? true;
    _reminders = c?.shiftReminders ?? true;
    _selfie = c?.selfieRequired ?? true;
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _pickTime(bool start) async {
    final m = AttendanceClock.parseMinutes(start ? _start : _end) ?? 540;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: m ~/ 60, minute: m % 60),
    );
    if (picked == null) return;
    final v =
        '${picked.hour.toString().padLeft(2, '0')}:'
        '${picked.minute.toString().padLeft(2, '0')}';
    setState(() => start ? _start = v : _end = v);
  }

  Future<void> _save() async {
    if (_start.compareTo(_end) >= 0) {
      return _snack('The day must end after it starts');
    }
    if (_days.isEmpty) return _snack('Pick at least one working day');
    final prov = Provider.of<UserProvider>(context, listen: false);
    final company = prov.company;
    if (company == null) return;
    setState(() => _busy = true);
    try {
      await sl<CompanyRepository>().updateSettings(company.id, {
        ...company.settings,
        'defaultShiftStart': _start,
        'defaultShiftEnd': _end,
        'workingDays': (_days.toList()..sort()),
        'lateAfterMinutes': _lateAfter,
        'checkoutInZone': _checkoutInZone,
        'shiftReminders': _reminders,
        'selfieRequired': _selfie,
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
    const fmt = AttendanceClock.formatShiftTime;
    const dayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    Widget timeBox(String label, String value, VoidCallback onTap) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FieldLabel(label),
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Container(
              height: 48,
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: colors.border),
              ),
              child: Text(
                fmt(value),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );

    Widget toggle(
      String title,
      String subtitle,
      bool value,
      ValueChanged<bool> onChanged,
    ) => SwitchListTile(
      value: value,
      onChanged: onChanged,
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 13)),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Hours & rules')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    timeBox('Starts', _start, () => _pickTime(true)),
                    const SizedBox(width: 12),
                    timeBox('Ends', _end, () => _pickTime(false)),
                  ],
                ),
                const SizedBox(height: 14),
                const FieldLabel('Working days'),
                Row(
                  children: [
                    for (var d = 1; d <= 7; d++) ...[
                      if (d > 1) const SizedBox(width: 6),
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(999),
                          onTap: () => setState(
                            () => _days.contains(d)
                                ? _days.remove(d)
                                : _days.add(d),
                          ),
                          child: Container(
                            height: 36,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: _days.contains(d)
                                  ? colors.brandSoft
                                  : colors.surface,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: _days.contains(d)
                                    ? colors.brand
                                    : colors.border,
                              ),
                            ),
                            child: Text(
                              dayLetters[d - 1],
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: _days.contains(d)
                                    ? colors.brandStrong
                                    : colors.textPrimary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 14),
                const FieldLabel('Mark late after'),
                AppSegmented<int>(
                  selected: _lateAfter,
                  onChanged: (v) => setState(() => _lateAfter = v),
                  segments: {for (final m in _lateOptions) m: '$m min'},
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppGroup(
            children: [
              toggle(
                'Check-out inside the zone',
                'Stops people punching out from home',
                _checkoutInZone,
                (v) => setState(() => _checkoutInZone = v),
              ),
              toggle(
                'Shift reminders',
                'Notify before start and if they forget to check out',
                _reminders,
                (v) => setState(() => _reminders = v),
              ),
              toggle(
                'Selfie on check-in',
                'Business plan',
                _selfie,
                (v) => setState(() => _selfie = v),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Individual shifts set on a person override these hours.',
            style: TextStyle(fontSize: 12, color: colors.textTertiary),
          ),
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
