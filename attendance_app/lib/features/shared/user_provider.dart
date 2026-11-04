import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'package:attendance_app/core/di/injection.dart';
import 'package:attendance_app/core/utils/logger.dart';
import 'package:attendance_app/domain/repositories/auth_repository.dart';
import 'package:attendance_app/domain/repositories/company_repository.dart';
import 'package:attendance_app/domain/repositories/employee_repository.dart';
import 'package:attendance_app/domain/repositories/location_repository.dart';
import 'package:attendance_app/data/models/company_model.dart';
import 'package:attendance_app/data/models/location_model.dart';
import 'package:attendance_app/data/models/user_model.dart';
import 'package:attendance_app/data/datasources/notification_service.dart';
import 'package:attendance_app/features/shared/offline_sync_manager.dart';

/// Holds the authenticated session (Firebase user → role-aware [UserModel] and
/// their [CompanyModel]) and drives the top-level auth routing.
class UserProvider with ChangeNotifier {
  UserProvider({
    AuthRepository? authRepository,
    CompanyRepository? companyRepository,
    EmployeeRepository? employeeRepository,
    LocationRepository? locationRepository,
    NotificationService? notificationService,
    OfflineSyncManager? offlineSyncManager,
  }) : _auth = authRepository ?? sl<AuthRepository>(),
       _company = companyRepository ?? sl<CompanyRepository>(),
       _employees = employeeRepository ?? sl<EmployeeRepository>(),
       _locations = locationRepository ?? sl<LocationRepository>(),
       _notifications = notificationService ?? sl<NotificationService>(),
       _offlineSync = offlineSyncManager ?? sl<OfflineSyncManager>() {
    _authSubscription = _auth.authStateChanges().listen(_onAuthChange);
  }

  final AuthRepository _auth;
  final CompanyRepository _company;
  final EmployeeRepository _employees;
  final LocationRepository _locations;
  final NotificationService _notifications;
  final OfflineSyncManager _offlineSync;

  UserModel? _user;
  CompanyModel? _companyModel;
  List<LocationModel> _sites = const [];
  bool _loading = true;
  StreamSubscription<User?>? _authSubscription;
  int _authChangeVersion = 0;

  UserModel? get user => _user;
  CompanyModel? get company => _companyModel;

  /// The employee's assigned work sites, primary first (a pre-v2 single
  /// work location shows up as one legacy site). Empty for admins.
  List<LocationModel> get sites => _sites;
  bool get loading => _loading;
  bool get isSuperAdmin => _user?.role == 'super_admin';
  bool get isAdmin => _user?.role == 'admin';
  bool get isEmployee => _user?.role == 'employee';

  /// Why the signed-in user may not use the app (deactivated employee or
  /// suspended company), or null when access is allowed. Security Rules
  /// enforce the same on every punch and leave request.
  String? get blockedReason {
    final user = _user;
    if (user == null || isSuperAdmin) return null;
    if (_companyModel?.status == 'suspended') {
      return 'Your company’s PunchIn access has been suspended. '
          'Contact your administrator.';
    }
    if (user.role == 'employee' && user.status != 'active') {
      return 'Your employee account has been deactivated. '
          'Contact your company admin.';
    }
    return null;
  }

  Future<void> _onAuthChange(User? firebaseUser) async {
    final version = ++_authChangeVersion;
    _loading = true;
    notifyListeners();
    if (firebaseUser != null) {
      try {
        final user = await _auth.resolveUser(firebaseUser.uid);
        final company = user?.companyId == null
            ? null
            : await _company.getCompany(user!.companyId!);
        final sites = await _loadSites(user);
        if (version != _authChangeVersion) return;
        _user = user;
        _companyModel = company;
        _sites = sites;
        if (user?.role == 'employee' &&
            user?.companyId != null &&
            blockedReason == null) {
          try {
            await _notifications.initialize(
              onToken: (token) =>
                  _employees.saveFcmToken(user!.companyId!, user.id, token),
            );
          } catch (error, stackTrace) {
            // Notification setup must never prevent a valid authenticated session.
            AppLogger.warn('FCM initialization failed: $error');
            AppLogger.debug('$stackTrace');
          }
          // Replay any attendance captured offline, then keep syncing on reconnect.
          _offlineSync.configure(user!.companyId!);
        }
      } catch (error, stackTrace) {
        if (version != _authChangeVersion) return;
        AppLogger.error(
          'Failed to resolve session',
          error: error,
          stackTrace: stackTrace,
        );
        _user = null;
        _companyModel = null;
        _sites = const [];
      }
    } else {
      _user = null;
      _companyModel = null;
      _sites = const [];
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> signIn(String email, String password) =>
      _auth.signIn(email: email, password: password);

  Future<void> signUpWithCode(
    String name,
    String email,
    String password,
    String code,
  ) async {
    await _auth.signUpWithCode(
      name: name,
      email: email,
      password: password,
      code: code,
    );
    await refreshUser();
  }

  Future<void> refreshUser() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    _user = await _auth.resolveUser(uid);
    if (_user?.companyId != null) {
      _companyModel = await _company.getCompany(_user!.companyId!);
    }
    _sites = await _loadSites(_user);
    notifyListeners();
  }

  /// Admins: moves legacy per-employee work locations into company sites the
  /// first time they sign in on a multi-site build. Employees: resolves
  /// their assigned sites.
  Future<List<LocationModel>> _loadSites(UserModel? user) async {
    final companyId = user?.companyId;
    if (user == null || companyId == null) return const [];
    try {
      if (user.role == 'admin') {
        await _locations.migrateLegacyLocations(companyId);
        return const [];
      }
      if (user.role != 'employee') return const [];
      if (user.locationIds.isEmpty) {
        final zone = user.workLocation;
        return zone?['latitude'] == null
            ? const []
            : [LocationModel.legacy(zone!)];
      }
      final all = await _locations.getLocations(companyId);
      final mine = all.where((l) => user.locationIds.contains(l.id)).toList()
        ..sort((a, b) {
          final pa = a.id == user.primaryLocationId;
          final pb = b.id == user.primaryLocationId;
          return pa == pb ? 0 : (pa ? -1 : 1);
        });
      return mine;
    } catch (error) {
      // Sites only drive the punch map; never block the session over them.
      AppLogger.warn('Could not load work sites: $error');
      return const [];
    }
  }

  Future<void> signOut() async {
    final user = _user;
    if (user?.role == 'employee' && user?.companyId != null) {
      try {
        await _employees.saveFcmToken(user!.companyId!, user.id, '');
      } catch (error) {
        // Signing out locally is more important than clearing a stale token.
        AppLogger.warn('Could not clear FCM token on sign-out: $error');
      }
    }
    _offlineSync.reset();
    await _auth.signOut();
    await _notifications.reset();
    _user = null;
    _companyModel = null;
    _sites = const [];
    notifyListeners();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _notifications.dispose();
    super.dispose();
  }
}
