import 'package:cloud_firestore/cloud_firestore.dart';

/// A punch the app refused because the person was outside every zone.
class PunchAttempt {
  const PunchAttempt({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.date,
    this.at,
    this.locationId,
    this.locationName,
    required this.distance,
    this.accuracy,
  });

  final String id;
  final String employeeId;
  final String employeeName;
  final String date; // 'yyyy-MM-dd', company time
  final DateTime? at;
  final String? locationId;
  final String? locationName;

  /// Metres from the nearest site's centre.
  final double distance;
  final double? accuracy;

  factory PunchAttempt.fromMap(Map<String, dynamic> m, String id) =>
      PunchAttempt(
        id: id,
        employeeId: m['employeeId'] ?? '',
        employeeName: m['employeeName'] ?? '',
        date: m['date'] ?? '',
        at: (m['at'] as Timestamp?)?.toDate(),
        locationId: m['locationId'] as String?,
        locationName: m['locationName'] as String?,
        distance: (m['distance'] as num?)?.toDouble() ?? 0,
        accuracy: (m['accuracy'] as num?)?.toDouble(),
      );
}

/// One person's failed tries on a day, summed up for the admin.
class FailedTries {
  const FailedTries(this.employeeId, this.employeeName, this.tries);

  final String employeeId;
  final String employeeName;
  final List<PunchAttempt> tries;

  int get count => tries.length;

  /// The closest they got, with the site it was measured from.
  PunchAttempt get closest =>
      tries.reduce((a, b) => a.distance <= b.distance ? a : b);

  static List<FailedTries> group(List<PunchAttempt> all) {
    final by = <String, List<PunchAttempt>>{};
    for (final a in all) {
      (by[a.employeeId] ??= []).add(a);
    }
    return [
      for (final e in by.entries)
        FailedTries(e.key, e.value.first.employeeName, e.value),
    ]..sort((a, b) => b.count.compareTo(a.count));
  }
}
