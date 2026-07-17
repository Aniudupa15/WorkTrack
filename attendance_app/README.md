# PunchIn

PunchIn is a Flutter workplace-attendance application backed by Firebase Authentication, Firestore, Cloud Functions, Cloud Storage, and Firebase Cloud Messaging. Employee provisioning, attendance timestamps, geofence validation, and late-status determination are server-authoritative.

## Architecture

- Flutter + Provider: mobile application and authenticated UI state.
- Firebase Authentication: email/password sign-in.
- Firestore: tenant-scoped companies, employees, attendance, and leave requests.
- Cloud Functions (`cloud_functions/`): privileged lifecycle and attendance operations.
- Cloud Storage: employee selfies and administrator-managed avatars.
- FCM: per-device employee reminders and leave-status notifications.

The application does not use a conventional REST server. Do not grant client-side writes to company roles, employee profiles, or attendance documents: the callable functions and rules are designed as one trust boundary.

## Prerequisites

- Flutter stable (Dart SDK compatible with `pubspec.yaml`)
- Node.js 20+
- Firebase CLI (`npm install -g firebase-tools`)
- A Firebase project with Authentication (Email/Password), Firestore, Storage, Functions, and Cloud Messaging enabled

## Local setup

1. In this directory, run `flutter pub get`.
2. Run `flutterfire configure` and commit the resulting `lib/firebase_options.dart` and platform configuration files.
3. Register Android/iOS app identifiers in Firebase. Keep the Android application ID aligned with the package name selected by FlutterFire; do not change it independently.
4. Install function dependencies: `cd cloud_functions && npm ci` (or `npm install` on first setup).
5. Start emulators for local development: `firebase emulators:start --only auth,firestore,storage,functions`.
6. Run the mobile app: `flutter run`.

## Production configuration and deployment

Set `ATTENDANCE_TIME_ZONE` (for example, `Asia/Kolkata`) and optionally `FUNCTION_REGION` in the Functions runtime environment. Configure any required email delivery provider before onboarding employees: the Admin SDK can generate reset links but does not send email by itself.

Deploy the backend and access controls from this directory:

```text
firebase deploy --only firestore:rules,firestore:indexes,storage,functions
```

Before a production release:

- Configure Android/iOS release signing in CI; never sign a release with debug keys.
- Enable Firebase App Check for Flutter, Firestore, Storage, and Functions.
- Set Firestore, Storage, and Functions budgets/alerts; enable Cloud Logging retention appropriate to your compliance requirements.
- Review Firebase Authentication password policy and authorized domains.
- Build and test each target (`flutter test`, `flutter analyze`, `flutter build appbundle`, and `flutter build ipa` on macOS).

## Data model and access model

`companies/{companyId}` owns `employees`, `attendance`, and `leaves` subcollections. `users/{uid}` is a server-owned role record. An administrator's company ID is their Firebase Auth UID.

Only Cloud Functions can create roles, provision employees, modify employee records, or record attendance. Employees can submit their own constrained leave requests and update only their own FCM token. Firestore and Storage rules must be deployed with the app; they are not optional configuration.

## Operations and troubleshooting

- **Permission denied:** confirm the user has a server-provisioned `/users/{uid}` document and deploy the latest rules.
- **Check-in rejected:** verify the employee is active, has a work location, granted precise location permission, and is within the assigned radius.
- **Missing push notification:** verify OS notification permission, the stored FCM token, and Firebase Messaging configuration. Tokens refresh automatically while the app is authenticated.
- **Firestore index error:** deploy `firestore.indexes.json`; do not create ad-hoc indexes that diverge from source control.
- **Employee welcome email:** configure an email provider or administrative delivery workflow. Password-reset links must be delivered through an approved channel and never displayed or logged in the client.

## Verification

```text
flutter analyze
flutter test
node --check cloud_functions/index.js
```
