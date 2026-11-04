/* eslint-disable no-console */
// Seeds the LOCAL Firebase emulators with a demo company so the app can be
// run and tested end-to-end without touching production.
//
//   firebase emulators:exec --only auth,firestore,storage \
//     "node cloud_functions/scripts/seed-emulator.js"   (from attendance_app/)
//
// or, with emulators already running:
//   FIRESTORE_EMULATOR_HOST=127.0.0.1:8085 FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 \
//     node cloud_functions/scripts/seed-emulator.js
//
// Demo sign-ins (emulator only — these accounts never exist in production):
//   admin     asha@demo.test     / punchin-demo-1
//   employee  ravi@demo.test     / punchin-demo-1
//   super     super@demo.test    / punchin-demo-1
//
// The main site is the Android emulator's default GPS fix (Googleplex,
// Mountain View) so punching in works out of the box. A second site sits
// ~2 km away; Priya and Deepa are assigned both. Arjun keeps only a pre-v2
// `workLocation` to exercise the legacy punch path.
//
// SEED_LEGACY=1 skips the location docs and gives everyone a pre-v2
// `workLocation` only, so the admin's first sign-in runs the migration.

process.env.FIRESTORE_EMULATOR_HOST ??= "127.0.0.1:8085";
process.env.FIREBASE_AUTH_EMULATOR_HOST ??= "127.0.0.1:9099";

const { initializeApp } = require("firebase-admin/app");
const { getAuth } = require("firebase-admin/auth");
const { getFirestore, Timestamp, FieldValue } = require("firebase-admin/firestore");

if (!process.env.FIRESTORE_EMULATOR_HOST.match(/^(127\.0\.0\.1|localhost)/)) {
  throw new Error("Refusing to seed: FIRESTORE_EMULATOR_HOST is not local.");
}

initializeApp({ projectId: "trackin-df4d8" });
const auth = getAuth();
const db = getFirestore();

const PASSWORD = "punchin-demo-1";
const COMPANY = "demo-bright-logistics";
const HQ = { latitude: 37.4219983, longitude: -122.084, radius: 150, address: "HQ — MG Road" };
const LEGACY = process.env.SEED_LEGACY === "1";
const SITES = {
  hq: { name: "Head office", address: "12, MG Road, Bengaluru", latitude: HQ.latitude, longitude: HQ.longitude, radius: 150, isMain: true },
  wh: { name: "Whitefield warehouse", address: "Plot 4, EPIP Zone, Whitefield", latitude: 37.4030, longitude: -122.0750, radius: 200, isMain: false },
};
const IST = 330 * 60 * 1000;

async function user(email, name) {
  try {
    return (await auth.getUserByEmail(email)).uid;
  } catch {
    return (await auth.createUser({ email, password: PASSWORD, displayName: name, emailVerified: true })).uid;
  }
}

function istDate(daysAgo) {
  const d = new Date(Date.now() + IST - daysAgo * 86400000);
  return d.toISOString().slice(0, 10);
}

function at(date, hhmm) {
  // date is the IST calendar day; convert IST wall time to a UTC instant.
  return Timestamp.fromDate(new Date(Date.parse(`${date}T${hhmm}:00Z`) - IST));
}

async function main() {
  const superUid = await user("super@demo.test", "PunchIn Support");
  const adminUid = await user("asha@demo.test", "Asha Rao");
  // [email, name, department, shift start, shift end, site ids (primary first)]
  const people = [
    ["ravi@demo.test", "Ravi Kumar", "Dispatch", "09:00", "18:00", ["hq"]],
    ["meera@demo.test", "Meera Shah", "Accounts", "10:00", "19:00", ["hq"]],
    ["arjun@demo.test", "Arjun K", "Dispatch", "09:00", "18:00", []],
    ["priya@demo.test", "Priya Nair", "Warehouse", "08:00", "17:00", ["wh", "hq"]],
    ["deepa@demo.test", "Deepa S", "Field", "09:30", "18:30", ["hq", "wh"]],
  ];

  const batch = db.batch();
  batch.set(db.doc(`users/${superUid}`), { role: "super_admin", name: "PunchIn Support", email: "super@demo.test" });
  batch.set(db.doc(`users/${adminUid}`), { role: "admin", companyId: COMPANY, viaCode: "SEED" });
  batch.set(db.doc(`companies/${COMPANY}`), {
    companyId: COMPANY, companyName: "Bright Logistics", adminId: adminUid, adminName: "Asha Rao",
    adminEmail: "asha@demo.test", phone: null, address: "12, MG Road, Bengaluru", status: "active",
    employeeCode: "BRT7K4Q", createdBy: superUid, createdAt: FieldValue.serverTimestamp(),
    totalEmployees: people.length,
    settings: { defaultRadius: 150, defaultShiftStart: "09:00", defaultShiftEnd: "18:00" },
  });
  batch.set(db.doc("codes/BRT7K4Q"), { companyId: COMPANY, type: "employee", companyName: "Bright Logistics" });
  if (!LEGACY) {
    for (const [id, site] of Object.entries(SITES)) {
      batch.set(db.doc(`companies/${COMPANY}/locations/${id}`), { ...site, createdAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp() });
    }
  }
  const zoneOf = (s) => ({ latitude: s.latitude, longitude: s.longitude, radius: s.radius, address: s.address });

  const uids = [];
  for (const [email, name, dept, start, end, siteIds] of people) {
    const uid = await user(email, name);
    const ids = LEGACY ? [] : siteIds;
    uids.push([uid, name, ids[0] ?? null]);
    batch.set(db.doc(`users/${uid}`), { role: "employee", companyId: COMPANY, viaCode: "BRT7K4Q" });
    batch.set(db.doc(`companies/${COMPANY}/employees/${uid}`), {
      uid, name, email, phone: null, department: dept, position: null, status: "active",
      avatarUrl: null,
      workLocation: ids.length ? zoneOf(SITES[ids[0]]) : HQ,
      locationIds: ids, primaryLocationId: ids[0] ?? null,
      shift: { start, end }, fcmToken: null,
      joinedAt: FieldValue.serverTimestamp(),
    });
  }

  // ~5 weeks of history (Mon–Sat), skipping today so the punch flow is fresh.
  for (const [uid, name, siteId] of uids) {
    const site = siteId ? SITES[siteId] : HQ;
    const siteFields = siteId ? { locationId: siteId, locationName: SITES[siteId].name } : {};
    for (let back = 1; back <= 35; back++) {
      const date = istDate(back);
      if (new Date(`${date}T00:00:00Z`).getUTCDay() === 0) continue; // Sunday off
      const roll = (back * 7 + name.length) % 23;
      const ref = db.doc(`companies/${COMPANY}/attendance/${uid}_${date}`);
      if (roll === 0) {
        batch.set(ref, { employeeId: uid, companyId: COMPANY, employeeName: name, date, checkIn: null, checkOut: null, status: "absent", isLate: false, checkInLocation: null, checkOutLocation: null, selfieStoragePath: null, isSynced: true, notes: "Seed" });
        continue;
      }
      const late = roll < 3;
      batch.set(ref, {
        employeeId: uid, companyId: COMPANY, employeeName: name, date,
        checkIn: at(date, late ? "09:27" : "08:56"), checkOut: at(date, "18:07"),
        status: late ? "late" : "present", isLate: late,
        checkInLocation: { latitude: site.latitude, longitude: site.longitude, accuracy: 9 },
        checkOutLocation: { latitude: site.latitude, longitude: site.longitude, accuracy: 11 },
        selfieStoragePath: null, isSynced: true, notes: null, ...siteFields,
      });
    }
  }

  const [ravi, meera, arjun] = uids;
  const leave = (id, [uid, name], type, from, to, reason, status, note = null) =>
    batch.set(db.doc(`companies/${COMPANY}/leaves/${id}`), {
      id, employeeId: uid, companyId: COMPANY, employeeName: name, type,
      startDate: Timestamp.fromDate(new Date(from)), endDate: Timestamp.fromDate(new Date(to)),
      reason, status, createdAt: FieldValue.serverTimestamp(), updatedAt: null, adminNote: note,
    });
  leave("l1", ravi, "casual", "2026-11-12", "2026-11-13", "Sister's wedding in Mysuru.", "pending");
  leave("l2", ravi, "casual", "2026-10-15", "2026-10-15", "Bank work", "approved", "Approved, enjoy.");
  leave("l3", meera, "sick", "2026-11-03", "2026-11-03", "Fever", "pending");
  leave("l4", arjun, "earned", "2026-11-20", "2026-11-24", "Family trip", "pending");

  await batch.commit();
  console.log(`Seeded company ${COMPANY}: 1 admin, ${people.length} employees, ${LEGACY ? "legacy work locations" : "2 sites"}, history and leaves.`);
}

main().catch((e) => { console.error(e); process.exit(1); });
