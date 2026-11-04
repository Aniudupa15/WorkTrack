import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:attendance_app/core/constants/app_constants.dart';
import 'package:attendance_app/core/theme/app_colors.dart';
import 'package:attendance_app/core/theme/app_spacing.dart';
import 'package:attendance_app/core/widgets/app_button.dart';
import 'package:attendance_app/core/widgets/avatar.dart';
import 'package:attendance_app/core/widgets/status_badge.dart';
import 'package:attendance_app/features/auth/login_screen.dart';
import 'package:attendance_app/features/onboarding/company_signup_screen.dart';
import 'package:attendance_app/features/onboarding/join_company_screen.dart';

/// First screen for signed-out users (design 1.1): what PunchIn does, then
/// register a company, join one, or sign in.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  static const _office = LatLng(12.9757, 77.6062);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    void open(Widget page) =>
        Navigator.push(context, MaterialPageRoute(builder: (_) => page));

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.asset(
                      'assets/images/logo.png',
                      width: 32,
                      height: 32,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'PunchIn',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                children: [
                  _Hero(colors: colors),
                  const SizedBox(height: 28),
                  const Text(
                    'Attendance your team can trust',
                    style: TextStyle(
                      fontSize: 30,
                      height: 36 / 30,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.6,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Location-verified punch-ins, live team view and '
                    'payroll-ready reports. Set up in five minutes.',
                    style: text.bodyMedium?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppButton(
                    label: 'Register your company',
                    onPressed: () => open(const CompanySignupScreen()),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppButton(
                    label: 'Join with an invite code',
                    variant: AppButtonVariant.secondary,
                    onPressed: () => open(const JoinCompanyScreen()),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Already have an account?', style: text.bodySmall),
                      TextButton(
                        onPressed: () => open(const LoginScreen()),
                        child: const Text('Sign in'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The illustrated map card: a work zone, the office pin, someone inside it
/// and the punch they just made.
class _Hero extends StatelessWidget {
  const _Hero({required this.colors});

  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.xxl),
      child: Container(
        height: 340,
        decoration: BoxDecoration(
          border: Border.all(color: colors.border),
          borderRadius: BorderRadius.circular(AppRadius.xxl),
        ),
        child: Stack(
          children: [
            IgnorePointer(
              child: FlutterMap(
                options: const MapOptions(
                  initialCenter: WelcomeScreen._office,
                  initialZoom: 16.3,
                ),
                children: [
                  TileLayer(
                    urlTemplate: AppConstants.osmTileUrl,
                    userAgentPackageName: AppConstants.packageName,
                  ),
                  CircleLayer(
                    circles: [
                      CircleMarker(
                        point: WelcomeScreen._office,
                        radius: 100,
                        useRadiusInMeter: true,
                        color: colors.brand.withValues(alpha: 0.12),
                        borderColor: colors.brand,
                        borderStrokeWidth: 2,
                      ),
                    ],
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: WelcomeScreen._office,
                        width: 36,
                        height: 36,
                        child: Container(
                          decoration: BoxDecoration(
                            color: colors.brand,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                          ),
                          child: const Icon(
                            Icons.business_rounded,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      Marker(
                        point: const LatLng(12.97605, 77.60655),
                        width: 20,
                        height: 20,
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x2E2563EB),
                                spreadRadius: 8,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: colors.border),
                  boxShadow: AppShadows.raised,
                ),
                child: Row(
                  children: [
                    const Avatar(name: 'Ravi Kumar'),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Ravi checked in',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            'HQ — MG Road · 42 m away',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ],
                      ),
                    ),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '09:03',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                        SizedBox(height: 2),
                        StatusBadge(status: 'present', label: 'On time'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
