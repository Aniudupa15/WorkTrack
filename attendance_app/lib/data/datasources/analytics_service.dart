import 'package:firebase_analytics/firebase_analytics.dart';

/// Thin wrapper over Firebase Analytics for screen-view and feature-usage
/// tracking. Keeping the SDK behind this facade means screens log intent
/// (`logCheckIn`) rather than depending on Firebase directly.
class AnalyticsService {
  AnalyticsService({FirebaseAnalytics? analytics})
    : _analytics = analytics ?? FirebaseAnalytics.instance;

  final FirebaseAnalytics _analytics;

  /// Navigator observer that logs screen views automatically.
  FirebaseAnalyticsObserver get observer =>
      FirebaseAnalyticsObserver(analytics: _analytics);

  Future<void> logLogin() => _analytics.logLogin(loginMethod: 'password');

  Future<void> logCheckIn({required bool offline}) => _analytics.logEvent(
    name: 'attendance_check_in',
    parameters: {'offline': offline ? 1 : 0},
  );

  Future<void> logCheckOut({required bool offline}) => _analytics.logEvent(
    name: 'attendance_check_out',
    parameters: {'offline': offline ? 1 : 0},
  );

  Future<void> logLeaveRequested(String type) =>
      _analytics.logEvent(name: 'leave_requested', parameters: {'type': type});

  Future<void> logReportExported() =>
      _analytics.logEvent(name: 'attendance_report_exported');
}
