import 'package:attendance_app/utils/color_schema.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'utils/user_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/admin/admin_dashboard.dart';
import 'screens/employee/employee_dashboard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()),
      ],
      child: const AttendanceApp(),
    ),
  );
}

class AttendanceApp extends StatelessWidget {
  const AttendanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Workplace Attendance',
      debugShowCheckedModeBanner: false,
      theme:     AppColors.lightTheme,
      darkTheme: AppColors.darkTheme,
      themeMode: ThemeMode.system,
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);

    if (userProvider.user == null) {
      return const LoginScreen();
    }

    if (userProvider.isAdmin) {
      return const AdminDashboard();
    }

    return const EmployeeDashboard();
  }
}
