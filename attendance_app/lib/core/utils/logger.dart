import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// Lightweight, centralized logging facade.
///
/// Wraps `dart:developer` so the app never calls `print` directly (which the
/// linter forbids in production code) and so every diagnostic flows through a
/// single, greppable choke point. In release builds informational logs are
/// suppressed; errors are always recorded and are the natural hook for wiring
/// Crashlytics later.
class AppLogger {
  const AppLogger._();

  static void debug(String message, {String name = 'punchin'}) {
    if (kDebugMode) {
      developer.log(message, name: name, level: 500);
    }
  }

  static void info(String message, {String name = 'punchin'}) {
    if (kDebugMode) {
      developer.log(message, name: name, level: 800);
    }
  }

  static void warn(String message, {String name = 'punchin'}) {
    developer.log(message, name: name, level: 900);
  }

  static void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    String name = 'punchin',
  }) {
    developer.log(
      message,
      name: name,
      level: 1000,
      error: error,
      stackTrace: stackTrace,
    );
  }
}
