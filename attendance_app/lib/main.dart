import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:attendance_app/bootstrap.dart';
import 'package:attendance_app/core/di/injection.dart';
import 'package:attendance_app/core/theme/app_theme.dart';
import 'package:attendance_app/core/widgets/app_loader.dart';
import 'package:attendance_app/data/datasources/analytics_service.dart';
import 'package:attendance_app/features/shared/user_provider.dart';
import 'package:attendance_app/features/auth/login_screen.dart';
import 'package:attendance_app/features/admin/admin_dashboard.dart';
import 'package:attendance_app/features/employee/employee_dashboard.dart';

Future<void> main() async {
  await bootstrap();
  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => UserProvider())],
      child: const AttendanceApp(),
    ),
  );
}

class AttendanceApp extends StatelessWidget {
  const AttendanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PunchIn',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
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

    if (userProvider.user == null) return const LoginScreen();
    if (userProvider.isAdmin) return const AdminDashboard();
    return const EmployeeDashboard();
  }
}
