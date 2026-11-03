import 'package:flutter_test/flutter_test.dart';

import 'package:attendance_app/core/theme/app_colors.dart';

void main() {
  group('AppColors.statusColor', () {
    const colors = AppColors.dark;

    test('present and approved map to success', () {
      expect(colors.statusColor('present'), colors.success);
      expect(colors.statusColor('approved'), colors.success);
    });

    test('late and pending map to warning', () {
      expect(colors.statusColor('late'), colors.warning);
      expect(colors.statusColor('pending'), colors.warning);
    });

    test('absent and rejected map to danger', () {
      expect(colors.statusColor('absent'), colors.danger);
      expect(colors.statusColor('rejected'), colors.danger);
    });

    test('leave and half day map to info', () {
      expect(colors.statusColor('leave'), colors.info);
      expect(colors.statusColor('half_day'), colors.info);
    });

    test('unknown status falls back to neutral grey', () {
      expect(colors.statusColor('whatever'), colors.textSecondary);
      expect(colors.statusSoftColor('whatever'), colors.surfaceMuted);
    });

    test('soft colours pair with their strong tone', () {
      expect(colors.statusSoftColor('present'), colors.successSoft);
      expect(colors.statusSoftColor('late'), colors.warningSoft);
      expect(colors.statusSoftColor('rejected'), colors.dangerSoft);
    });
  });
}
