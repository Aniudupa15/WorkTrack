import 'package:cloud_functions/cloud_functions.dart';

/// Where the app's server functions run.
///
/// The project has no Blaze billing, so Cloud Functions can't be deployed;
/// the same code runs as a web service on Render (`cloud_functions/server.js`)
/// and the app calls it by URL. Build with `--dart-define=BACKEND_URL=` (empty)
/// to go back to Cloud Functions once billing works.
const backendUrl = String.fromEnvironment(
  'BACKEND_URL',
  defaultValue: 'https://punchin-api.onrender.com',
);

const _emulators = bool.fromEnvironment('USE_FIREBASE_EMULATORS');

/// A callable for [name] on whichever backend this build uses. The Render
/// free plan can take a while to wake, hence the longer timeout.
HttpsCallable backendCallable(FirebaseFunctions functions, String name) =>
    _emulators || backendUrl.isEmpty
    ? functions.httpsCallable(name)
    : functions.httpsCallableFromUrl(
        '$backendUrl/call/$name',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 90)),
      );
