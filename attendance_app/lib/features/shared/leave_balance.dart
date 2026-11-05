import 'package:attendance_app/data/models/company_model.dart';
import 'package:attendance_app/data/models/leave_model.dart';

/// Leave types with a yearly allowance ('other' has none).
const quotaLeaveTypes = ['casual', 'sick', 'earned'];

/// Default yearly allowance per type when the company hasn't set one.
const defaultLeaveQuota = {'casual': 8, 'sick': 7, 'earned': 15};

/// Days a year the company allows for [type], or null for 'other'.
int? leaveQuota(CompanyModel? company, String type) {
  if (!quotaLeaveTypes.contains(type)) return null;
  final set = company?.settings['leaveQuota'];
  final v = set is Map ? set[type] : null;
  return (v as num?)?.toInt() ?? defaultLeaveQuota[type];
}

/// Working days in [start]..[end] (inclusive), halved for a half day.
double leaveDays(
  DateTime start,
  DateTime end, {
  required List<int> workingDays,
  String dayPart = 'full',
}) {
  var n = 0;
  for (
    var d = DateTime(start.year, start.month, start.day);
    !d.isAfter(end);
    d = d.add(const Duration(days: 1))
  ) {
    if (workingDays.contains(d.weekday)) n++;
  }
  return dayPart == 'full' ? n.toDouble() : n * 0.5;
}

double leaveDaysOf(LeaveModel l, List<int> workingDays) => leaveDays(
  l.startDate,
  l.endDate,
  workingDays: workingDays,
  dayPart: l.dayPart,
);

/// Days of [type] used this [year]: approved, plus pending when [pending].
double leaveUsed(
  List<LeaveModel> leaves,
  String type,
  int year,
  List<int> workingDays, {
  bool pending = false,
}) => leaves
    .where(
      (l) =>
          l.type == type &&
          l.startDate.year == year &&
          (l.status == 'approved' || (pending && l.status == 'pending')),
    )
    .fold(0.0, (sum, l) => sum + leaveDaysOf(l, workingDays));

/// "2", "1.5" — whole numbers without the decimal.
String fmtDays(double d) =>
    d == d.roundToDouble() ? '${d.round()}' : d.toStringAsFixed(1);

/// The company's holidays, sorted by date ('yyyy-MM-dd').
List<({String date, String name})> holidaysOf(CompanyModel? company) {
  final raw = company?.settings['holidays'];
  if (raw is! List) return const [];
  return [
    for (final h in raw)
      if (h is Map && h['date'] is String)
        (date: h['date'] as String, name: (h['name'] as String?) ?? 'Holiday'),
  ]..sort((a, b) => a.date.compareTo(b.date));
}

/// The holiday's name when [day] ('yyyy-MM-dd') is one, else null.
String? holidayOn(CompanyModel? company, String day) {
  for (final h in holidaysOf(company)) {
    if (h.date == day) return h.name;
  }
  return null;
}
