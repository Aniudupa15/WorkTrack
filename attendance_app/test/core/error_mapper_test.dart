import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:attendance_app/core/error/app_exception.dart';

void main() {
  group('ErrorMapper', () {
    test('passes an existing AppException through unchanged', () {
      const original = AppException('already friendly', code: 'x');
      expect(ErrorMapper.map(original), same(original));
    });

    test('uses the Cloud Function HttpsError message when present', () {
      final error = FirebaseFunctionsException(
        message: 'You are outside the work location radius',
        code: 'permission-denied',
      );
      final mapped = ErrorMapper.map(error);
      expect(mapped.message, 'You are outside the work location radius');
      expect(mapped.code, 'permission-denied');
    });

    test('maps auth codes to friendly copy without leaking internals', () {
      final mapped = ErrorMapper.map(
        FirebaseAuthException(code: 'wrong-password'),
      );
      expect(mapped.message, 'Incorrect email or password.');
    });

    test('falls back to a generic message for unknown errors', () {
      final mapped = ErrorMapper.map(Exception('boom'));
      expect(mapped.message, 'Something went wrong. Please try again.');
    });
  });
}
