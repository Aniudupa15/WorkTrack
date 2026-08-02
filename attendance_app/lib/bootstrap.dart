import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:attendance_app/core/di/injection.dart';
import 'package:attendance_app/data/datasources/offline_attendance_store.dart';
import 'package:attendance_app/firebase_options.dart';

/// Handles FCM messages received while the app is terminated or backgrounded.
///
/// Must be a top-level function so it can run in its own isolate.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

/// One-time application bootstrap: platform bindings, Firebase, local cache,
/// messaging, and the dependency-injection graph. Called once from `main`.
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await Hive.initFlutter();
  await Hive.openBox(OfflineAttendanceStore.boxName);
  final prefs = await SharedPreferences.getInstance();
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  _wireCrashReporting();
  configureDependencies(prefs);
}

/// Routes uncaught Flutter framework and platform (async) errors to
/// Crashlytics. Collection is disabled in debug builds so local runs don't
/// pollute the dashboard.
void _wireCrashReporting() {
  final crashlytics = FirebaseCrashlytics.instance;
  crashlytics.setCrashlyticsCollectionEnabled(!kDebugMode);

  final previousOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    crashlytics.recordFlutterFatalError(details);
    previousOnError?.call(details);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    crashlytics.recordError(error, stack, fatal: true);
    return true;
  };
}
