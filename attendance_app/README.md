# PunchIn

PunchIn is a Flutter attendance app on Firebase. A company sets up its work sites; employees punch in and out only
when they are inside one of their assigned sites, and the time and late status come from the server clock, not the
phone.

## What it does

**Employees** sign in with their phone number (SMS code), join their company from an invite, a company code or a QR
code, and punch in at the nearest assigned site. They see their month on a calendar, request leave and get shift
reminders.

**Admins** sign up with email, set up the company and its main location, and get a 14-day Pro trial. They invite
people by phone (one at a time or from an Excel/CSV list), approve code joiners, manage locations and shifts, review
attendance logs (with punch selfies on Business), approve leave, see monthly reports and export them, including
payroll layouts for Zoho Payroll, Keka and TallyPrime.

**Plans** (per employee, before 18% GST): Free (up to 5 people, 30 days of history), Pro ₹49/month or ₹39/month billed
yearly, and Business ₹99/month or ₹79/month billed yearly (selfie verification and payroll export). Billing is Razorpay Subscriptions with UPI
AutoPay or card.

## How it is put together

- **App** — Flutter, Provider for session state, `get_it` for wiring repositories to Firebase data sources
  (`lib/data`), screens in `lib/features`. `lib/core/billing/entitlements.dart` decides what a company's plan allows.
- **Firestore** — `companies/{id}` with `employees`, `locations`, `attendance` and `leaves` subcollections;
  `users/{uid}` holds each person's role; `codes/{code}` are join codes; `invites/{phone}` are phone invites.
- **Security Rules** (`firestore.rules`) are the authority for punches: server timestamp, company-time date and late
  status, an assigned site that the GPS fix falls inside, one record per person per day, and the Free plan's limits.
- **Cloud Functions** (`cloud_functions/index.js`) do everything a client must not: create companies, join people,
  import invites, reset codes, run billing (Razorpay subscriptions, the signed webhook, seat sync), send shift
  reminders and mark absences.
- **Storage** holds punch selfies; only the employee and their admin can read them.

Company time is IST (UTC+05:30) in the app (`AttendanceClock`), the Rules and the Functions; change all three together.

## Running it locally

Needs Flutter (stable), Node 20+ and the Firebase CLI.

```bash
flutter pub get
npm --prefix cloud_functions install
firebase emulators:start --only auth,firestore,storage,functions --project trackin-df4d8
node cloud_functions/scripts/seed-emulator.js
flutter run --dart-define=USE_FIREBASE_EMULATORS=true
```

The seed creates "Bright Logistics" with two sites, five employees, five weeks of history and some leave. Demo sign-ins
(emulator only): admin `asha@demo.test`, employees `ravi@demo.test` and others, password `punchin-demo-1`. Phone sign-in
codes appear in the Auth emulator (`/emulator/v1/projects/trackin-df4d8/verificationCodes`).

Billing under the emulator uses a built-in fake Razorpay (keys in the git-ignored `cloud_functions/.secret.local`
starting with `rzp_fake_`), so no real account is touched.

## Tests

```bash
flutter analyze && flutter test                        # app
npm --prefix cloud_functions test                       # reminder logic
npm --prefix test/rules install && npm --prefix test/rules test   # Security Rules (Firestore emulator running)
node test/functions/functions.test.mjs                  # onboarding + billing end to end (all emulators running)
```

## Deploying

See [`../DEPLOYMENT.md`](../DEPLOYMENT.md): Blaze plan, phone sign-in and SHA keys, Razorpay plans, secrets and webhook,
then rules, functions and the app release together.

## Troubleshooting

- **"The server rejected this punch"** — the person is outside every assigned site, the shift is over, or the phone's
  clock is far off. Check their sites in Team and that location is set to precise.
- **Phone sign-in fails in a release build** — the app's SHA-1/SHA-256 aren't registered in Firebase, or Play
  Integrity isn't enabled.
- **"Payments aren't set up yet"** — the Razorpay secrets aren't set for the deployed functions.
- **A company is stuck on Free after paying** — check the Razorpay webhook is configured and its deliveries succeed;
  `firebase functions:log --only razorpayWebhook`.
