import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'package:attendance_app/core/di/injection.dart';
import 'package:attendance_app/core/utils/logger.dart';
import 'package:attendance_app/domain/repositories/auth_repository.dart';
import 'package:attendance_app/domain/repositories/company_repository.dart';
import 'package:attendance_app/domain/repositories/employee_repository.dart';
import 'package:attendance_app/data/models/company_model.dart';
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
    NotificationService? notificationService,
    OfflineSyncManager? offlineSyncManager,
  }) : _auth = authRepository ?? sl<AuthRepository>(),
       _company = companyRepository ?? sl<CompanyRepository>(),
       _employees = employeeRepository ?? sl<EmployeeRepository>(),
       _notifications = notificationService ?? sl<NotificationService>(),
       _offlineSync = offlineSyncManager ?? sl<OfflineSyncManager>() {
    _authSubscription = _auth.authStateChanges().listen(_onAuthChange);
  }

  final AuthRepository _auth;
  final CompanyRepository _company;
  final EmployeeRepository _employees;
  final NotificationService _notifications;
  final OfflineSyncManager _offlineSync;

  UserModel? _user;
  CompanyModel? _companyModel;
  bool _loading = true;
  StreamSubscription<User?>? _authSubscription;
  int _authChangeVersion = 0;

  UserModel? get user => _user;
  CompanyModel? get company => _companyModel;
  bool get loading => _loading;
  bool get isAdmin => _user?.role == 'admin';
  bool get isEmployee => _user?.role == 'employee';

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
        if (version != _authChangeVersion) return;
        _user = user;
        _companyModel = company;
        if (user?.role == 'employee' && user?.companyId != null) {
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
      }
    } else {
      _user = null;
      _companyModel = null;
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> signIn(String email, String password) =>
      _auth.signIn(email: email, password: password);

  Future<void> signUpAdmin(
    String name,
    String email,
    String password,
    String companyName,
  ) async {
    await _auth.signUpAdmin(
      name: name,
      email: email,
      password: password,
      companyName: companyName,
    );
    await refreshUser();
  }

  Future<void> signUpEmployee(
    String name,
    String email,
    String password,
    String companyCode,
  ) async {
    await _auth.signUpEmployee(
      name: name,
      email: email,
      password: password,
      companyCode: companyCode,
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
    notifyListeners();
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
    notifyListeners();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _notifications.dispose();
    super.dispose();
  }
}
