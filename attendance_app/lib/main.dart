import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:attendance_app/bootstrap.dart';
import 'package:attendance_app/core/di/injection.dart';
import 'package:attendance_app/core/theme/app_theme.dart';
import 'package:attendance_app/core/widgets/app_loader.dart';
import 'package:attendance_app/data/datasources/analytics_service.dart';
import 'package:attendance_app/features/shared/theme_controller.dart';
import 'package:attendance_app/features/shared/user_provider.dart';
import 'package:attendance_app/features/auth/login_screen.dart';
import 'package:attendance_app/features/admin/admin_dashboard.dart';
import 'package:attendance_app/features/admin/super_admin_console.dart';
import 'package:attendance_app/features/employee/employee_dashboard.dart';
import 'package:attendance_app/features/onboarding/company_setup_screen.dart';
import 'package:attendance_app/features/onboarding/join_team_screen.dart';

Future<void> main() async {
  await bootstrap();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider.value(value: sl<ThemeController>()),
      ],
      child: const AttendanceApp(),
    ),
  );
}

class AttendanceApp extends StatelessWidget {
  const AttendanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Editorial red/black/white is a light-first identity — the app is locked
    // to light so the crisp paper-and-ink look is what every user sees.
    return MaterialApp(
      title: 'PunchIn',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.light,
      themeMode: ThemeMode.light,
      navigatorObservers: [sl<AnalyticsService>().observer],
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);

    if (userProvider.loading) {
      return const Scaffold(body: AppLoader());
    }

    if (userProvider.sessionError) {
      return const _AccessBlockedScreen(
        message:
            'We couldn’t load your account. Check your internet '
            'connection and try again.',
        retry: true,
      );
    }
    if (userProvider.needsOnboarding) {
      return userProvider.signedInWithPhone
          ? const JoinTeamScreen()
          : const CompanySetupScreen();
    }
    if (userProvider.user == null) return const LoginScreen();
    final blocked = userProvider.blockedReason;
    if (blocked != null) {
      return _AccessBlockedScreen(
        message: blocked,
        pending: userProvider.isPendingApproval,
      );
    }
    if (userProvider.isSuperAdmin) return const SuperAdminConsole();
    if (userProvider.isAdmin) return const AdminDashboard();
    return const EmployeeDashboard();
  }
}

class _AccessBlockedScreen extends StatelessWidget {
  const _AccessBlockedScreen({
    required this.message,
    this.pending = false,
    this.retry = false,
  });

  final String message;

  /// Waiting for approval rather than locked out: friendlier, with a refresh.
  final bool pending;

  /// Loading failed: offer to try again instead of a lock.
  final bool retry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  pending
                      ? Icons.hourglass_top_rounded
                      : retry
                      ? Icons.cloud_off_rounded
                      : Icons.lock_outline_rounded,
                  size: 56,
                ),
                const SizedBox(height: 16),
                Text(
                  pending
                      ? 'Waiting for approval'
                      : retry
                      ? 'Couldn’t load your account'
                      : 'Access unavailable',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(message, textAlign: TextAlign.center),
                const SizedBox(height: 24),
                if (pending || retry) ...[
                  FilledButton(
                    onPressed: () => Provider.of<UserProvider>(
                      context,
                      listen: false,
                    ).completeOnboarding(),
                    child: Text(retry ? 'Try again' : 'Check again'),
                  ),
                  const SizedBox(height: 12),
                ],
                OutlinedButton(
                  onPressed: () => Provider.of<UserProvider>(
                    context,
                    listen: false,
                  ).signOut(),
                  child: const Text('Sign out'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
