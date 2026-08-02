<div align="center">

<img src="assets/images/logo.png" alt="PunchIn Logo" width="480"/>

# PunchIn — Smart Workplace Attendance

**GPS-verified • Firebase-powered • No backend server required**

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=flat-square&logo=flutter&logoColor=white)](https://flutter.dev)
[![Firebase](https://img.shields.io/badge/Firebase-Firestore%20%7C%20Auth%20%7C%20FCM-FFCA28?style=flat-square&logo=firebase&logoColor=black)](https://firebase.google.com)
[![Dart](https://img.shields.io/badge/Dart-3.2+-0175C2?style=flat-square&logo=dart&logoColor=white)](https://dart.dev)
[![License](https://img.shields.io/badge/License-MIT-green?style=flat-square)](LICENSE)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen?style=flat-square)](CONTRIBUTING.md)

[Features](#-features) · [Screenshots](#-screenshots) · [Tech Stack](#-tech-stack) · [Getting Started](#-getting-started) · [Architecture](#-architecture) · [Contributing](#-contributing)

</div>

---

## 📌 Overview

**PunchIn** is a full-featured mobile attendance tracking app built with **Flutter** and **Firebase**. It eliminates fake attendance, enforces GPS-based geofencing, and gives admins real-time workforce visibility — all without a single backend server.

> No Node.js. No Docker. No managed database. Firebase handles everything.

### Why PunchIn?

| Problem | PunchIn's Solution |
|---|---|
| Fake / proxy attendance | GPS geofence + optional face selfie verification |
| Manual register tracking | Digital check-in / check-out with timestamps |
| No real-time visibility | Live admin dashboard with Firestore streams |
| Poor connectivity areas | Offline mode with auto background sync |
| Complex backend setup | 100% Firebase — deploy in minutes |

---

## ✨ Features

### 👨‍💼 Employee
- **One-tap Check-In / Check-Out** with GPS verification
- **Location status** — real-time "Within Zone" / "Outside Zone" indicator
- **Auto late detection** — flagged if checking in past grace period
- **Personal attendance history** — monthly calendar view + stats
- **Leave management** — apply for sick, casual, annual, or unpaid leave
- **Push notifications** — shift reminders and leave status alerts
- **Offline mode** — mark attendance without internet, syncs automatically on reconnect
- **Light & dark themes** — follows your system appearance

### 🏢 Admin
- **Live dashboard** — present, absent, and late counts update in real time
- **Employee management** — add, edit, deactivate employees
- **Work location picker** — pin location on an interactive map, set geofence radius
- **Shift scheduling** — assign start/end times per employee
- **Attendance logs** — filterable by date, employee, and status
- **Leave approvals** — approve or reject with admin notes
- **Reports & analytics** — charts, trends, and one-tap CSV export via the share sheet
- **Auto-send credentials** — new employees receive login details by email automatically

---

## 📱 Screenshots

<div align="center">

| Login | Employee Dashboard | Check-In |
|:---:|:---:|:---:|
| <img src="screenshots/login.png" width="200"/> | <img src="screenshots/employee_dashboard.png" width="200"/> | <img src="screenshots/checkin.png" width="200"/> |

| Admin Dashboard | Attendance Logs | Reports |
|:---:|:---:|:---:|
| <img src="screenshots/admin_dashboard.png" width="200"/> | <img src="screenshots/logs.png" width="200"/> | <img src="screenshots/reports.png" width="200"/> |

</div>

> Screenshots will be added after the first stable release. Want to contribute screenshots? See [Contributing](#-contributing).

---

## 🛠 Tech Stack

| Layer | Technology | Purpose |
|---|---|---|
| **Mobile** | Flutter (Dart ≥ 3.8) | Cross-platform iOS & Android |
| **Architecture** | Feature-first Clean Architecture | `core` / `domain` / `data` / `features` layering |
| **DI** | get_it | Service locator — repositories resolved, never `new`'d in the UI |
| **State** | Provider (`ChangeNotifier`) | Session + lightweight screen state |
| **Auth** | Firebase Authentication | Email/password login, auto credential emails |
| **Database** | Cloud Firestore | Real-time NoSQL — all app data |
| **Functions** | Firebase Cloud Functions (Node 20) | Server-authoritative check-in/out, reminders, offline sync |
| **Notifications** | Firebase Cloud Messaging | Leave alerts and shift reminders |
| **Storage** | Firebase Cloud Storage | Check-in selfies and avatars |
| **Analytics** | Firebase Analytics | Screen views + feature-usage events |
| **Maps** | flutter_map + OpenStreetMap | Interactive maps — **no API key, no billing** |
| **Offline** | Hive queue + connectivity_plus | Capture attendance offline, replay on reconnect |
| **Reports** | share_plus + path_provider | On-device CSV export via the share sheet |
| **Charts** | fl_chart | Analytics visuals |
| **Theming** | Material 3 + `ThemeExtension` | Semantic color tokens, light **and** dark |

---

## 🗂 Project Structure

The Flutter app lives in [`attendance_app/`](attendance_app); the layers below make dependencies point inward (`features → domain ← data`, everything on `core`).

```
attendance_app/
├── lib/
│   ├── main.dart                     # MaterialApp, themes, auth routing
│   ├── bootstrap.dart                # Firebase + Hive + FCM + DI init
│   ├── firebase_options.dart         # Generated by FlutterFire CLI
│   ├── core/
│   │   ├── constants/                # FirestorePaths, AppConstants
│   │   ├── di/injection.dart         # get_it service locator
│   │   ├── error/                    # AppException + ErrorMapper
│   │   ├── theme/                    # AppColors (tokens), AppTheme, spacing
│   │   ├── utils/logger.dart         # AppLogger
│   │   └── widgets/                  # AppLoader, EmptyState, StatusBadge, …
│   ├── domain/
│   │   └── repositories/             # Abstract contracts (DI boundary)
│   ├── data/
│   │   ├── models/                   # user / company / attendance / leave
│   │   ├── datasources/              # Firebase wrappers, offline store, etc.
│   │   └── repositories/             # Concrete impls (map errors, add offline)
│   └── features/
│       ├── auth/                     # login, signup
│       ├── admin/                    # dashboard, employees, logs, leaves, analytics, map picker
│       ├── employee/                 # dashboard, mark attendance, history, leaves
│       └── shared/                   # UserProvider, OfflineSyncManager
├── cloud_functions/                  # Firebase Cloud Functions (Node.js)
│   ├── index.js
│   └── package.json
├── firestore.rules · storage.rules   # Security Rules
├── firestore.indexes.json
└── firebase.json
```

---

## 🗄 Firestore Schema

```
/companies/{companyId}
    ├── companyName, adminEmail, settings { defaultRadius, shiftStart, shiftEnd }
    │
    ├── /employees/{uid}
    │       ├── name, email, phone, department, position, status
    │       ├── workLocation { latitude, longitude, radius, address }
    │       ├── shift { start: "09:00", end: "18:00" }
    │       └── fcmToken
    │
    ├── /attendance/{docId}
    │       ├── employeeId, date ("YYYY-MM-DD"), status
    │       ├── checkIn (Timestamp), checkOut (Timestamp)
    │       ├── isLate, checkInLocation { lat, lng, accuracy }
    │       └── selfieStoragePath, isSynced
    │
    └── /leaves/{docId}
            ├── employeeId, type, startDate, endDate
            ├── reason, status ("pending" | "approved" | "rejected")
            └── adminNote
```

---

## 🚀 Getting Started

### Prerequisites

- Flutter SDK `>=3.2.0`
- Dart SDK `>=3.2.0`
- Firebase account (free Spark plan works)
- Android Studio / Xcode for device emulation
- Node.js `>=18` (for Cloud Functions only)

---

### Step 1 — Clone the repo

```bash
git clone https://github.com/your-username/punchin.git
cd punchin
```

### Step 2 — Create your Firebase project

1. Go to [console.firebase.google.com](https://console.firebase.google.com) → **Add project**
2. Enable these services under **Build**:
   - Authentication → Email/Password provider
   - Firestore Database → Production mode
   - Cloud Storage → Default region
   - Cloud Functions
   - Cloud Messaging

### Step 3 — Connect Flutter to Firebase

```bash
# Install FlutterFire CLI
dart pub global activate flutterfire_cli

# Auto-configure — select your Firebase project when prompted
flutterfire configure
```

This generates `lib/firebase_options.dart` automatically. Commit this file.

### Step 4 — Install Flutter dependencies

```bash
flutter pub get
```

### Step 5 — Deploy Firestore Security Rules

```bash
npm install -g firebase-tools
firebase login
firebase deploy --only firestore:rules
```

### Step 6 — Deploy Cloud Functions

```bash
cd functions
npm install
cd ..
firebase deploy --only functions
```

### Step 7 — Run the app

```bash
flutter run
```

For a release build:

```bash
# Android
flutter build apk --release

# iOS
flutter build ipa --release
```

---

## 🔐 Firestore Security Rules

Access control is enforced entirely through Firestore rules — no server middleware needed.

```js
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    function isAdmin(compId) {
      return request.auth != null &&
        get(/databases/$(database)/documents/users/$(request.auth.uid))
          .data.role == 'admin' &&
        get(/databases/$(database)/documents/users/$(request.auth.uid))
          .data.companyId == compId;
    }

    function isEmployee(compId, empId) {
      return request.auth != null && request.auth.uid == empId &&
        get(/databases/$(database)/documents/users/$(request.auth.uid))
          .data.companyId == compId;
    }

    match /companies/{companyId} {
      allow read, write: if isAdmin(companyId);
    }

    match /companies/{companyId}/employees/{empId} {
      allow read:  if isAdmin(companyId) || isEmployee(companyId, empId);
      allow write: if isAdmin(companyId);
    }

    match /companies/{companyId}/attendance/{docId} {
      allow read:   if isAdmin(companyId) || isEmployee(companyId, resource.data.employeeId);
      allow create: if isEmployee(companyId, request.resource.data.employeeId);
      allow update: if isAdmin(companyId) || isEmployee(companyId, resource.data.employeeId);
      allow delete: if isAdmin(companyId);
    }

    match /companies/{companyId}/leaves/{docId} {
      allow read:   if isAdmin(companyId) || isEmployee(companyId, resource.data.employeeId);
      allow create: if isEmployee(companyId, request.resource.data.employeeId);
      allow update: if isAdmin(companyId);
    }
  }
}
```

---

## ☁️ Cloud Functions

All writes to identity, role, attendance, and employee documents are **server-owned** — the client can only read them and flip its own FCM token (see Security Rules).

| Function | Trigger | What it does |
|---|---|---|
| `registerCompany` | HTTPS Callable | Provisions company + admin role atomically on signup |
| `onEmployeeCreated` | HTTPS Callable | Creates the employee's Auth account + sends a password-reset (welcome) link |
| `updateEmployee` | HTTPS Callable | Validated update of an employee's profile / shift / work location |
| `onCheckIn` | HTTPS Callable | Server-side geofence validation, duplicate protection, late detection |
| `onCheckOut` | HTTPS Callable | Records checkout time and finalizes the record |
| `syncOfflineAttendance` | HTTPS Callable | Replays a batch of offline events, validated at sync time |
| `autoMarkAbsent` | Scheduled (23:59) | Marks active employees with no check-in as absent |
| `sendShiftReminders` | Scheduled (every 5 min) | FCM check-in reminder before shift start, check-out reminder after shift end |
| `onLeaveCreated` | Firestore `onCreate` | Notifies admin of a new leave request |
| `onLeaveStatusChanged` | Firestore `onUpdate` | FCM-notifies the employee of approval/rejection |

> Monthly attendance reports are generated **on-device as CSV** and shared via the platform share sheet (no server round-trip required).

---

## 🗺 Maps — No API Key Required

PunchIn uses **[flutter_map](https://pub.dev/packages/flutter_map)** with free **OpenStreetMap** tiles instead of Google Maps.

```yaml
# pubspec.yaml — no Google Maps, no API key, no billing
flutter_map: ^7.0.2
latlong2: ^0.9.1
```

```dart
FlutterMap(
  options: MapOptions(
    center: LatLng(workLat, workLng),
    zoom: 17.0,
  ),
  children: [
    TileLayer(
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      userAgentPackageName: 'com.punchin.app',
    ),
    CircleLayer(circles: [
      CircleMarker(
        point: LatLng(workLat, workLng),
        radius: allowedRadiusMeters,
        useRadiusInMeter: true,
        color: isWithin
            ? Colors.green.withOpacity(0.2)
            : Colors.red.withOpacity(0.2),
        borderColor: isWithin ? Colors.green : Colors.red,
        borderStrokeWidth: 2,
      ),
    ]),
  ],
)
```

---

## 📦 All Dependencies

```yaml
dependencies:
  flutter:
    sdk: flutter

  # Firebase
  firebase_core: ^3.1.0
  firebase_auth: ^5.1.0
  cloud_firestore: ^5.1.0
  firebase_storage: ^12.1.0
  firebase_messaging: ^15.0.0
  cloud_functions: ^4.6.0
  firebase_analytics: ^11.1.0

  # Maps — no API key needed
  flutter_map: ^7.0.2
  latlong2: ^0.9.1
  geolocator: ^13.0.1
  geocoding: ^3.0.0

  # UI & Utilities
  provider: ^6.1.2
  fl_chart: ^0.68.0
  flutter_local_notifications: ^17.2.0
  image_picker: ^1.1.2
  hive_flutter: ^1.1.0
  intl: ^0.19.0
  uuid: ^4.3.3
  connectivity_plus: ^6.0.3
  permission_handler: ^11.3.1
  shared_preferences: ^2.2.3
  path_provider: ^2.1.3
```

---

## 🏗 Architecture

```
Flutter App
    │
    ├── Firebase Authentication    ← Login, session, credential emails
    │
    ├── Cloud Firestore            ← All data, real-time streams
    │       └── Security Rules     ← Role-based access, no middleware
    │
    ├── Firebase Cloud Functions   ← Business logic, scheduling, reports
    │
    ├── Firebase Cloud Messaging   ← Push notifications (via Functions)
    │
    ├── Firebase Cloud Storage     ← Selfies, avatars, PDF reports
    │
    └── flutter_map + OSM          ← Maps & geofencing (no API key)
```

On the client, the app follows **feature-first Clean Architecture**. The UI depends only on abstract repository interfaces (`domain/`), resolved through a `get_it` service locator; concrete implementations (`data/`) wrap the Firebase datasources, translate errors into a single `AppException`, and add the offline-capture path. This keeps business logic testable and Firebase swappable.

**Offline flow:** when the device is offline a check-in/out is written to a durable Hive queue instead of failing. `OfflineSyncManager` replays the queue on login and on every reconnect through `syncOfflineAttendance`, which re-validates each event server-side — so geofence and late-status stay authoritative even for events captured earlier.

---

## 🧪 Testing

```bash
cd attendance_app
flutter test                 # unit + widget tests
flutter analyze              # static analysis (kept at zero issues)
dart format --set-exit-if-changed .   # formatting check
```

---

## 🤖 CI/CD

GitHub Actions workflows live in [`.github/workflows`](.github/workflows):

- **`flutter_ci.yml`** — on every pull request and push to `main`/`develop`: `flutter analyze`, formatting check, and `flutter test`, with Flutter/pub caching.
- **`release.yml`** — on push to `main` (or manual dispatch): builds a release **APK** and **AAB**, attaches them to an auto-tagged **GitHub Release** with generated notes, and caches Gradle.

### Release signing

`release.yml` signs the bundle when these repository **secrets** are present (otherwise it falls back to debug signing):

| Secret | Description |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | Base64 of your `upload-keystore.jks` |
| `ANDROID_STORE_PASSWORD` | Keystore password |
| `ANDROID_KEY_ALIAS` | Key alias |
| `ANDROID_KEY_PASSWORD` | Key password |

Generate an upload keystore locally (keep it out of git):

```bash
keytool -genkey -v -keystore upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
base64 -w0 upload-keystore.jks   # paste into the ANDROID_KEYSTORE_BASE64 secret
```

---

## 📦 Building Locally

```bash
cd attendance_app
flutter build apk --release        # → build/app/outputs/flutter-apk/app-release.apk
flutter build appbundle --release  # → build/app/outputs/bundle/release/app-release.aab
```

---

## 🤝 Contributing

Contributions are welcome! Here's how to get started:

1. Fork the repository
2. Create a feature branch — `git checkout -b feature/your-feature`
3. Commit your changes — `git commit -m 'Add your feature'`
4. Push to the branch — `git push origin feature/your-feature`
5. Open a Pull Request

Please read [CONTRIBUTING.md](CONTRIBUTING.md) and follow the [code of conduct](CODE_OF_CONDUCT.md).

### Ideas for contributions

- [ ] Biometric login (fingerprint / Face ID)
- [ ] Bulk employee import via CSV
- [ ] WhatsApp notification integration
- [ ] Web admin portal (Flutter Web)
- [ ] Multi-location support per employee
- [ ] Payroll integration hooks

---

## 📄 License

This project is licensed under the **MIT License** — see [LICENSE](LICENSE) for details.

---

## 🙏 Acknowledgements

- [Flutter](https://flutter.dev) — the framework that makes one codebase run everywhere
- [Firebase](https://firebase.google.com) — the backend that needs no backend
- [flutter_map](https://pub.dev/packages/flutter_map) — free maps without the API key headache
- [OpenStreetMap](https://www.openstreetmap.org) — free map tiles for everyone
- [fl_chart](https://pub.dev/packages/fl_chart) — beautiful Flutter charts

---

<div align="center">

Made with ❤️ using Flutter & Firebase

**[⬆ Back to top](#punchin--smart-workplace-attendance)**

</div>
