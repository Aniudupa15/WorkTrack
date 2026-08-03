import 'package:get_it/get_it.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:attendance_app/data/datasources/analytics_service.dart';
import 'package:attendance_app/data/datasources/connectivity_service.dart';
import 'package:attendance_app/data/datasources/offline_attendance_store.dart';
import 'package:attendance_app/data/datasources/report_service.dart';
import 'package:attendance_app/features/shared/theme_controller.dart';
import 'package:attendance_app/features/shared/offline_sync_manager.dart';
import 'package:attendance_app/data/repositories/attendance_repository_impl.dart';
import 'package:attendance_app/data/repositories/auth_repository_impl.dart';
import 'package:attendance_app/data/repositories/company_repository_impl.dart';
import 'package:attendance_app/data/repositories/employee_repository_impl.dart';
import 'package:attendance_app/data/repositories/leave_repository_impl.dart';
import 'package:attendance_app/domain/repositories/attendance_repository.dart';
import 'package:attendance_app/domain/repositories/auth_repository.dart';
import 'package:attendance_app/domain/repositories/company_repository.dart';
import 'package:attendance_app/domain/repositories/employee_repository.dart';
import 'package:attendance_app/domain/repositories/leave_repository.dart';
import 'package:attendance_app/data/datasources/attendance_service.dart';
import 'package:attendance_app/data/datasources/auth_service.dart';
import 'package:attendance_app/data/datasources/database_service.dart';
import 'package:attendance_app/data/datasources/location_service.dart';
import 'package:attendance_app/data/datasources/notification_service.dart';
import 'package:attendance_app/data/datasources/storage_service.dart';

/// Global service locator.
final GetIt sl = GetIt.instance;

/// Registers the app's dependency graph.
///
/// Data sources (thin Firebase wrappers) are registered as lazy singletons and
/// composed into domain repositories, which are the only thing the presentation
/// layer depends on. Swapping an implementation — or a fake, in tests — is a
/// one-line change here and nowhere else.
void configureDependencies(SharedPreferences prefs) {
  sl.registerSingleton<SharedPreferences>(prefs);

  // ── Data sources (Firebase wrappers) ────────────────────────────────────────
  sl
    ..registerLazySingleton<AuthService>(AuthService.new)
    ..registerLazySingleton<DatabaseService>(DatabaseService.new)
    ..registerLazySingleton<AttendanceService>(AttendanceService.new)
    ..registerLazySingleton<StorageService>(StorageService.new)
    ..registerLazySingleton<LocationService>(LocationService.new)
    ..registerLazySingleton<NotificationService>(NotificationService.new)
    ..registerLazySingleton<ConnectivityService>(ConnectivityService.new)
    ..registerLazySingleton<AnalyticsService>(AnalyticsService.new)
    ..registerLazySingleton<ReportService>(ReportService.new)
    ..registerLazySingleton<OfflineAttendanceStore>(
      () => OfflineAttendanceStore(Hive.box(OfflineAttendanceStore.boxName)),
    );

  // ── Repositories (domain contracts) ─────────────────────────────────────────
  sl
    ..registerLazySingleton<AuthRepository>(
      () => AuthRepositoryImpl(sl(), sl()),
    )
    ..registerLazySingleton<CompanyRepository>(
      () => CompanyRepositoryImpl(sl()),
    )
    ..registerLazySingleton<EmployeeRepository>(
      () => EmployeeRepositoryImpl(sl()),
    )
    ..registerLazySingleton<AttendanceRepository>(
      () => AttendanceRepositoryImpl(sl(), sl(), sl()),
    )
    ..registerLazySingleton<LeaveRepository>(() => LeaveRepositoryImpl(sl()));

  // ── App services ────────────────────────────────────────────────────────────
  sl
    ..registerLazySingleton<OfflineSyncManager>(
      () => OfflineSyncManager(sl(), sl()),
    )
    ..registerLazySingleton<ThemeController>(() => ThemeController(sl()));
}
