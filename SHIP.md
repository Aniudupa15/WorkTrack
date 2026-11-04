# Ship PunchIn 2.0 — checklist

Everything that can be done without you is done and committed. The boxes below need **you**, because they involve a payment,
secrets, or your Google sign-in. Do them in this order. Total time is about 45 minutes, plus Play review.

## Already done
- [x] v2 app: redesign, multiple sites, self-serve signup, OTP join, invites/QR/bulk upload, billing, payroll export
- [x] Tests: 34 Flutter, 6 reminders, 37 functions (emulator), 106 security-rules
- [x] Release bundle **v2.0.0 (20)**, signed with your upload key: `store/release/punchin-2.0.0-20.aab`
- [x] Store assets: `store/icon-512.png`, `store/feature-graphic.png`, `store/screenshots/*.png`, text in `store/listing.md`
- [x] Promo video: `store/promo/punchin-promo.mp4`
- [x] Leads: `marketing/leads.csv` (25 Bengaluru SMBs), pitch kit `marketing/pitch.md`, 20 Gmail drafts waiting in Drafts

## 1. Firebase: Blaze + phone sign-in (10 min) — you
1. Firebase console → trackin-df4d8 → **Upgrade to Blaze**. Set a budget alert (e.g. ₹1,000).
2. Authentication → Sign-in method → enable **Phone** (Email/Password is already on).
3. Project settings → Android app → add **SHA-1 and SHA-256** from Play Console → *Test and release → App integrity*
   (both the app-signing key and the upload key).

## 2. Razorpay (15 min) — you
Follow `DEPLOYMENT.md` §1b: create the 4 plans, put their ids in `attendance_app/cloud_functions/.env`, then:
```bash
cd attendance_app
firebase functions:secrets:set RAZORPAY_KEY_ID --account aniudupa15@gmail.com
firebase functions:secrets:set RAZORPAY_KEY_SECRET --account aniudupa15@gmail.com
firebase functions:secrets:set RAZORPAY_WEBHOOK_SECRET --account aniudupa15@gmail.com
```
Start with **test-mode** keys; switch to live after one test purchase works.

## 3. Deploy backend (5 min) — you
```bash
cd attendance_app
npm --prefix cloud_functions install
firebase deploy --only functions,firestore:indexes,storage --account aniudupa15@gmail.com
```
Then add the Razorpay webhook (DEPLOYMENT.md §1b step 4).

**Do not deploy `firestore:rules` yet** — see step 5.

## 4. Play Console (10 min + review) — you
1. Play Console → PunchIn → *Production* → **Create new release** → upload `store/release/punchin-2.0.0-20.aab`.
2. Release notes: copy from `store/listing.md`.
3. *Store presence → Main store listing*: replace the icon, feature graphic and phone screenshots with the files in
   `store/`; update the short/full description.
4. *App content → Data safety*: add **Phone number** and **Purchase history** (see `store/listing.md`).
5. Roll out to **100%** (a staged rollout leaves old-version users stuck after step 5). Send for review.

## 5. Security rules cut-over — you, after Play approves 2.0
The hardened rules reject punches from the old 1.1.0 app (they wrote device timestamps and a single work location),
and the 2.0 app needs the new rules for multiple sites. So deploy rules **the same day 2.0 goes live**:
```bash
firebase deploy --only firestore:rules --account aniudupa15@gmail.com
flutter build web --release
firebase deploy --only hosting --account aniudupa15@gmail.com
```
(The web app ships here too, since it is the 2.0 client.)
Tell existing customers to update the app that day. Play auto-updates most phones within 24 h.

## 6. Sales — you
- Open Gmail → Drafts → review and send the 20 PunchIn drafts (ideally 9–11 am IST, a few at a time).
- Call / WhatsApp the 5 phone-only leads in `marketing/leads.csv` using the script in `marketing/pitch.md`.
- Follow up after 3 days (template in `pitch.md`). Mark replies in the CSV's `status` column.
- Post the promo video on LinkedIn / WhatsApp Status with the Play Store link.
