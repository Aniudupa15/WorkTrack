import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:attendance_app/core/theme/app_theme.dart';
import 'package:attendance_app/core/widgets/status_badge.dart';

Widget _host(Widget child) => MaterialApp(
  theme: AppTheme.light,
  home: Scaffold(body: Center(child: child)),
);

void main() {
  group('StatusBadge', () {
    testWidgets('renders the status as a sentence-case label', (tester) async {
      await tester.pumpWidget(_host(const StatusBadge(status: 'present')));
      expect(find.text('Present'), findsOneWidget);
    });

    testWidgets('prefers an explicit label over the status', (tester) async {
      await tester.pumpWidget(
        _host(const StatusBadge(status: 'present', label: 'active')),
      );
      expect(find.text('active'), findsOneWidget);
      expect(find.text('Present'), findsNothing);
    });
  });
}
