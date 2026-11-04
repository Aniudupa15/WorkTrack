import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
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
  await _useEmulatorsIfRequested();
  await Hive.initFlutter();
  await Hive.openBox(OfflineAttendanceStore.boxName);
  final prefs = await SharedPreferences.getInstance();
  // Push and Crashlytics are mobile-only; the web app is for admins.
  if (!kIsWeb) {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    _wireCrashReporting();
  }
  configureDependencies(prefs);
}

/// Development only: `--dart-define=USE_FIREBASE_EMULATORS=true` points Auth,
/// Firestore, Storage and Functions at the local Firebase emulator suite
/// (10.0.2.2 is the host machine from an Android emulator; the browser uses
/// localhost). Never set in release builds.
Future<void> _useEmulatorsIfRequested() async {
  const enabled = bool.fromEnvironment('USE_FIREBASE_EMULATORS');
  if (!enabled || kReleaseMode) return;
  const configured = String.fromEnvironment('FIREBASE_EMULATOR_HOST');
  final host = configured.isNotEmpty
      ? configured
      : (kIsWeb ? 'localhost' : '10.0.2.2');
  await FirebaseAuth.instance.useAuthEmulator(host, 9099);
  FirebaseFirestore.instance.useFirestoreEmulator(host, 8085);
  await FirebaseStorage.instance.useStorageEmulator(host, 9199);
  FirebaseFunctions.instanceFor(
    region: 'asia-south1',
  ).useFunctionsEmulator(host, 5001);
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
