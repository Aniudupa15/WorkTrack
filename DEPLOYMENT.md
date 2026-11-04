# PunchIn — Deployment Guide

End-to-end guide to release the Android app (in [`attendance_app/`](attendance_app)) to the Google Play Store, plus deploying the Firebase backend. iOS notes are at the end.

All Flutter commands run from the `attendance_app/` directory:

```bash
cd attendance_app
```

---

## 0. Prerequisites

- Flutter stable (`flutter --version`), Android SDK, JDK 17.
- Firebase CLI (`npm i -g firebase-tools`) and `firebase login`.
- A Google Play Developer account (one-time US$25).
- FlutterFire configured (`lib/firebase_options.dart` and `android/app/google-services.json` present).

---

## 1. Deploy the Firebase backend

PunchIn v2 needs the **Blaze** plan (Cloud Functions, phone sign-in, scheduled jobs).

### 1a. One-time setup in the Firebase console

- **Authentication → Sign-in method:** enable **Email/Password** and **Phone**.
- **Project settings → Your apps → Android:** add the app's **SHA-1 and SHA-256** (from Play Console → App integrity, plus your upload key) so phone sign-in works.

### 1b. Razorpay (billing)

1. In the Razorpay dashboard (start in **Test mode**), create four **Subscription plans**. The amount is the
   per-seat price **including 18% GST**; the app sends the seat count as the subscription quantity.

   | Plan | Period | Amount per seat (₹, incl. GST) |
   |---|---|---|
   | Pro monthly | monthly, every 1 | 57.82 |
   | Pro yearly | yearly, every 1 | 552.24 |
   | Business monthly | monthly, every 1 | 116.82 |
   | Business yearly | yearly, every 1 | 1118.64 |

   (Per-seat prices before GST: Pro ₹49/mo or ₹468/yr, Business ₹99/mo or ₹948/yr — the same numbers as
   `lib/core/billing/entitlements.dart` and `PRICES` in `cloud_functions/index.js`. Change all three together.)
2. Copy `cloud_functions/.env.example` to `cloud_functions/.env` and fill in the four plan ids.
3. Set the secrets (you'll be prompted for each value; they never go in the repo):

   ```bash
   firebase functions:secrets:set RAZORPAY_KEY_ID
   firebase functions:secrets:set RAZORPAY_KEY_SECRET
   firebase functions:secrets:set RAZORPAY_WEBHOOK_SECRET
   ```
4. After the first deploy, add a webhook in Razorpay → **Settings → Webhooks**:
   - URL: `https://asia-south1-trackin-df4d8.cloudfunctions.net/razorpayWebhook`
   - Secret: the same value as `RAZORPAY_WEBHOOK_SECRET`
   - Events: all `subscription.*` events.
5. Switch to **Live mode** keys and plans only after a test-mode purchase works end to end.

### 1c. Deploy

Rules, functions and the new app version depend on each other — deploy them together.

```bash
cd attendance_app
npm --prefix cloud_functions install
firebase deploy --only firestore:rules,firestore:indexes,storage,functions
```

- **Rules**: `firestore.rules`, `storage.rules` — punches are verified against the server clock and the employee's
  assigned sites; companies, joins, invites and billing fields are written only by functions; Free companies are held
  to 5 people and 30 days of admin history.
- **Functions**: `cloud_functions/index.js` — onboarding (`registerCompany`, `claimJoin`, `importEmployees`,
  `resetJoinCode`), billing (`createSubscription`, `verifySubscription`, `cancelSubscription`, `listInvoices`,
  `razorpayWebhook`, `onEmployeeWritten`), reminders, auto-absent and leave hooks.
- Companies created before billing have no `plan` field and stay unrestricted ("Classic"). Set `plan: "trial"` and a
  `trialEndsAt` on them in the console if you want to move them onto billing.

Verify: `firebase functions:list` and `firebase functions:log`.

### Local testing

```bash
cd attendance_app
firebase emulators:start --only auth,firestore,storage,functions --project trackin-df4d8
node cloud_functions/scripts/seed-emulator.js        # demo company
node test/functions/functions.test.mjs               # onboarding + billing (fake Razorpay)
npm --prefix test/rules install && npm --prefix test/rules test
flutter run --dart-define=USE_FIREBASE_EMULATORS=true
```

Under the emulator, `cloud_functions/.secret.local` (git-ignored) holds `rzp_fake_…` keys that switch billing to a
built-in fake, so no Razorpay account is touched.

---

## 2. Set the application id

The template id `com.example.attendance_app` **cannot be published**. Choose your own (e.g. `com.yourcompany.punchin`) and:

1. In the [Firebase console](https://console.firebase.google.com) → Project settings → **Add app → Android**, register the new package name.
2. Download the new `google-services.json` into `android/app/`.
3. Update `android/app/build.gradle.kts`:
   ```kotlin
   namespace = "com.yourcompany.punchin"
   defaultConfig { applicationId = "com.yourcompany.punchin" }
   ```
4. (Optional) rename the Kotlin package dir under `android/app/src/main/kotlin/…` and `MainActivity.kt`'s `package` line to match.
5. Re-run `flutterfire configure` if you prefer it to regenerate the config.

---

## 3. Versioning

Bump `version:` in `pubspec.yaml` before each release — `versionName+versionCode`:

```yaml
version: 1.0.0+1   # → 1.0.1+2 → 1.1.0+3 …
```

`versionCode` (after `+`) **must strictly increase** for every upload to Play.

---

## 4. Generate an upload keystore

Do this **once**; keep the `.jks` and passwords safe and out of git.

```bash
keytool -genkey -v -keystore upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Place it at `android/app/upload-keystore.jks` and create `android/key.properties`
(copy `android/key.properties.example`):

```
storeFile=upload-keystore.jks
storePassword=<your-store-password>
keyAlias=upload
keyPassword=<your-key-password>
```

Both files are gitignored. Signing is already wired in `android/app/build.gradle.kts`
(reads `key.properties`, falls back to debug signing when absent).

---

## 5. Build the release App Bundle (AAB)

```bash
flutter clean
flutter pub get
flutter build appbundle --release
# → build/app/outputs/bundle/release/app-release.aab
```

APK (for sideload testing only): `flutter build apk --release`.

R8/code shrinking is off by default. To enable, add to the `release` block in
`build.gradle.kts` and test thoroughly (keep-rules for reflection-based libs):

```kotlin
isMinifyEnabled = true
isShrinkResources = true
```

### CI alternative

Pushing to `main` runs [`.github/workflows/release.yml`](.github/workflows/release.yml),
which builds the APK + AAB and publishes a GitHub Release. To sign in CI, add repo
**secrets**: `ANDROID_KEYSTORE_BASE64` (`base64 -w0 upload-keystore.jks`),
`ANDROID_STORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`.

---

## 6. Test the release build

```bash
flutter install --release          # onto a connected device
```

Smoke-test: admin signup, add employee, employee login, check-in inside the
geofence, offline check-in → reconnect sync, leave request/approval, CSV export,
light/dark toggle in Settings.

---

## 7. Play Console — create & configure the app

1. [play.google.com/console](https://play.google.com/console) → **Create app** (name, language, App/Free).
2. **App integrity → Play App Signing**: keep enabled (recommended); your upload key signs, Google re-signs.
3. **Store listing**: app name, short & full description, app icon (512×512), feature graphic (1024×500), phone screenshots (≥2).
4. **Store settings**: category *Business/Productivity*, contact email.

---

## 8. Data safety & app content

- **Data safety**: declare collected data — email (account), **precise location** (attendance geofencing), photos (check-in selfies), device identifiers (FCM). State encryption in transit and how users can request deletion.
- **Privacy policy**: host a URL and add it (required because location + camera are used). A placeholder must be replaced with a real policy before production.
- **App content**: target audience, ads (none), permissions declaration — justify `ACCESS_FINE_LOCATION` (background not used) and `CAMERA`.

---

## 9. Release tracks (roll out gradually)

Create a release on **Testing → Internal testing** first, then promote:

1. **Internal testing** — up to 100 testers by email; instant availability. Upload the AAB here first.
2. **Closed testing** — a wider tester list / Google Group.
3. **Open testing** — public opt-in beta.
4. **Production** — full rollout (use a staged % rollout).

For each: **Create new release → upload `app-release.aab` → add release notes → review → roll out.**

---

## 10. Post-launch monitoring

- **Crashlytics** — [console](https://console.firebase.google.com) → Crashlytics. Uncaught Flutter and async errors are already reported (see `bootstrap.dart`); collection is disabled in debug. Trigger a test crash once to confirm data flows.
- **Analytics** — Firebase → Analytics for screen views and the custom events (`attendance_check_in/out`, `leave_requested`, `attendance_report_exported`, `login`).
- **Play Console → Android vitals** for ANRs/crashes and **Statistics** for installs.

---

## 11. Shipping updates

1. Bump `version:` in `pubspec.yaml` (increment `versionCode`).
2. `flutter build appbundle --release`.
3. Play Console → Production → **Create new release** → upload → release notes → staged rollout.
4. Redeploy backend if functions/rules changed: `firebase deploy --only functions,firestore:rules`.

---

## iOS (optional)

```bash
cd ios && pod install && cd ..
flutter build ipa --release
```

Then open `build/ios/archive/*.xcarchive` in Xcode / Transporter and upload to
**App Store Connect → TestFlight → App Store**. Requires an Apple Developer
account and the iOS app registered in Firebase.
