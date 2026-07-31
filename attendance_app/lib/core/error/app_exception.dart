import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// A single, presentation-safe exception type.
///
/// The data layer catches raw Firebase/platform exceptions and rethrows them as
/// [AppException] with a message that is safe to show a user. The UI therefore
/// never has to interpolate a raw `$e` (which can leak internals) and can rely
/// on `exception.message` being human-readable.
class AppException implements Exception {
  const AppException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => 'AppException(${code ?? 'unknown'}): $message';
}

/// Translates infrastructure exceptions into a user-facing [AppException].
class ErrorMapper {
  const ErrorMapper._();

  static AppException map(Object error) {
    if (error is AppException) return error;
    if (error is FirebaseFunctionsException) {
      return AppException(_functionsMessage(error), code: error.code);
    }
    if (error is FirebaseAuthException) {
      return AppException(_authMessage(error), code: error.code);
    }
    if (error is FirebaseException) {
      return AppException(
        error.message ?? 'A network or database error occurred.',
        code: error.code,
      );
    }
    return const AppException('Something went wrong. Please try again.');
  }

  static String _functionsMessage(FirebaseFunctionsException e) {
    // Cloud Functions deliberately return friendly messages via HttpsError; use
    // them when present, otherwise fall back on the code.
    if (e.message != null && e.message!.trim().isNotEmpty) return e.message!;
    switch (e.code) {
      case 'unauthenticated':
        return 'Please sign in again to continue.';
      case 'permission-denied':
        return 'You do not have permission to do that.';
      case 'already-exists':
        return 'This action has already been completed.';
      case 'failed-precondition':
        return 'This action is not available right now.';
      default:
        return 'The server could not complete the request.';
    }
  }

  static String _authMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'That email address is not valid.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'email-already-in-use':
        return 'An account already exists for that email.';
      case 'weak-password':
        return 'Please choose a stronger password.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'No internet connection. Please check your network.';
      default:
        return e.message ?? 'Authentication failed. Please try again.';
    }
  }
}
