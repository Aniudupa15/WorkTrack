/* eslint-disable no-console */
// Emulator only: moves the demo company to Bengaluru coordinates and makes
// "today" look like a live working day (shift starting now, a few punches),
// for store screenshots and demos at any hour.
process.env.FIRESTORE_EMULATOR_HOST ??= "127.0.0.1:8085";
if (!process.env.FIRESTORE_EMULATOR_HOST.match(/^(127\.0\.0\.1|localhost)/)) throw new Error("not local");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, Timestamp } = require("firebase-admin/firestore");
initializeApp({ projectId: "trackin-df4d8" });
const db = getFirestore();
const C = "demo-bright-logistics";
const IST = 330 * 60000;
const SITES = {
  hq: { latitude: 12.9757, longitude: 77.6062, radius: 150 },
  wh: { latitude: 12.9784, longitude: 77.7266, radius: 200 },
};
const hhmm = (m) => `${String(Math.floor(m / 60) % 24).padStart(2, "0")}:${String(m % 60).padStart(2, "0")}`;

(async () => {
  const nowIst = new Date(Date.now() + IST);
  const date = nowIst.toISOString().slice(0, 10);
  const nowMin = nowIst.getUTCHours() * 60 + nowIst.getUTCMinutes();
  const start = Math.max(0, nowMin - 40); // shift began 40 minutes ago
  const shift = { start: hhmm(start), end: "23:59" };
  const ts = (min) => Timestamp.fromDate(new Date(Date.parse(`${date}T${hhmm(min)}:00Z`) - IST));
  const comp = db.doc(`companies/${C}`);
  for (const [id, s] of Object.entries(SITES)) await comp.collection("locations").doc(id).set(s, { merge: true });
  // Late after 60 min tonight, so Ravi can still punch "on time".
  await comp.set({ settings: { lateAfterMinutes: 30 } }, { merge: true });
  const emps = await comp.collection("employees").get();
  const plan = { "Meera Shah": -36, "Priya Nair": -2, "Deepa S": -31, "Arjun K": null };
  for (const e of emps.docs) {
    const d = e.data();
    const site = SITES[d.primaryLocationId || "hq"] || SITES.hq;
    await e.ref.update({
      shift, workLocation: { ...site, address: d.primaryLocationId === "wh" ? "Plot 4, EPIP Zone, Whitefield" : "12, MG Road, Bengaluru" },
    });
    const ref = comp.collection("attendance").doc(`${e.id}_${date}`);
    await ref.delete();
    const off = plan[d.name];
    if (off === undefined || off === null) continue;
    const inMin = nowMin + off;
    const late = inMin - start > 30;
    await ref.set({
      employeeId: e.id, companyId: C, employeeName: d.name, date,
      checkIn: ts(inMin), checkOut: null, status: late ? "late" : "present", isLate: late,
      checkInLocation: { ...site, accuracy: 8 }, checkOutLocation: null, selfieStoragePath: null,
      isSynced: true, notes: null, locationId: d.primaryLocationId || "hq",
    });
  }
  console.log("demo day ready", date, shift);
})();
