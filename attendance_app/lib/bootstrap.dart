import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:hive_flutter/hive_flutter.dart';

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
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  configureDependencies();
}
