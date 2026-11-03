import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:attendance_app/core/theme/app_colors.dart';
import 'package:attendance_app/core/theme/app_spacing.dart';
import 'package:attendance_app/core/widgets/app_button.dart';
import 'package:attendance_app/core/widgets/app_card.dart';
import 'package:attendance_app/core/widgets/entity_tile.dart';
import 'package:attendance_app/core/widgets/status_badge.dart';
import 'package:attendance_app/data/models/attendance_model.dart';

/// Confirmation after a successful punch: the server-recorded time, the
/// status, and what was verified.
class PunchSuccessScreen extends StatelessWidget {
  const PunchSuccessScreen({
    super.key,
    required this.record,
    required this.checkedOut,
    required this.locationName,
    required this.distanceMeters,
    required this.withSelfie,
  });

  final AttendanceModel record;
  final bool checkedOut;
  final String locationName;
  final double? distanceMeters;
  final bool withSelfie;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final time = DateFormat('h:mm a');
    final at = checkedOut ? record.checkOut : record.checkIn;
    final status = record.isLate ? 'late' : 'present';

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Close',
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.xxl,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        children: [
          Center(
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: colors.successSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check_rounded, size: 42, color: colors.success),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Center(
            child: checkedOut
                ? const StatusBadge(status: 'present', label: 'Checked out')
                : StatusBadge(
                    status: status,
                    label: record.isLate ? 'Late' : 'On time',
                  ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            at != null ? time.format(at) : '—',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 48,
              height: 52 / 48,
              fontWeight: FontWeight.w700,
              letterSpacing: -1.2,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          Text(
            checkedOut
                ? 'You’re checked out · worked ${record.workDurationFormatted}'
                : 'You’re checked in · ${DateFormat('EEE, d MMM').format(at ?? DateTime.now())}',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.xxl),
          AppGroup(
            children: [
              EntityTile(
                inGroup: true,
                title: 'Location',
                trailing: _value(locationName),
              ),
              if (distanceMeters != null)
                EntityTile(
                  inGroup: true,
                  title: 'Distance',
                  trailing: _value('${distanceMeters!.round()} m inside'),
                ),
              EntityTile(
                inGroup: true,
                title: 'Verified with',
                trailing: _value(withSelfie ? 'GPS + selfie' : 'GPS'),
              ),
              const EntityTile(
                inGroup: true,
                title: 'Time source',
                trailing: Text('Server clock'),
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(AppSpacing.lg),
        child: AppButton(
          label: 'Done',
          onPressed: () => Navigator.pop(context),
        ),
      ),
    );
  }

  Widget _value(String text) => Text(
    text,
    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
  );
}
