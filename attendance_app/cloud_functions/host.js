// Runs the same functions outside Google Cloud (the Render server, server.js), for
// projects without a Blaze billing account:
//   - handleCall: the Firebase callable protocol over plain HTTPS, so the app
//     can use httpsCallableFromUrl against it.
//   - tick: every 5 minutes, stands in for the Firestore triggers and
//     schedules (reminders, headcount, leave pushes, end-of-day absences).
const functions = require("./index");
const { getAuth } = require("firebase-admin/auth");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");
const { HttpsError } = require("firebase-functions/v2/https");

const db = getFirestore();
const TIME_ZONE = process.env.ATTENDANCE_TIME_ZONE || "Asia/Kolkata";

// Only these are reachable over HTTP.
const CALLABLES = new Set([
  "registerCompany", "claimJoin", "deleteMyAccount", "importEmployees", "resetJoinCode",
  "createSubscription", "verifySubscription", "cancelSubscription", "listInvoices",
]);

const MEMBERSHIP_CALLS = new Set(["claimJoin", "deleteMyAccount", "importEmployees", "registerCompany"]);

async function companyOf(uid) {
  return (await db.collection("users").doc(uid).get()).data()?.companyId || null;
}

async function recountCompany(companyId) {
  const ref = db.collection("companies").doc(companyId);
  const [company, snap] = await Promise.all([
    ref.get(),
    ref.collection("employees").where("status", "in", ["active", "pending"]).count().get(),
  ]);
  if (company.exists && company.data().activeEmployees !== snap.data().count) {
    await ref.update({ activeEmployees: snap.data().count });
  }
}

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "Authorization, Content-Type, X-Firebase-AppCheck, X-Firebase-GMPID, Firebase-Instance-ID-Token",
  "Access-Control-Max-Age": "3600",
};

function reply(status, body) {
  return { status, headers: { ...CORS, "Content-Type": "application/json" }, body: JSON.stringify(body) };
}

function errorReply(error) {
  const e = error instanceof HttpsError ? error : new HttpsError("internal", "INTERNAL");
  if (!(error instanceof HttpsError)) console.error("callable failed", error);
  return reply(e.httpErrorCode.status, { error: e.toJSON() });
}

/** method, name, authorization header, raw body text → {status, headers, body}. */
async function handleCall({ method, name, authorization, body }) {
  if (method === "OPTIONS") return { status: 204, headers: CORS, body: "" };
  if (method !== "POST") return reply(405, { error: { status: "INVALID_ARGUMENT", message: "POST only" } });
  if (!CALLABLES.has(name) || !functions[name]?.run) return reply(404, { error: { status: "NOT_FOUND", message: "Unknown function" } });
  let data;
  try {
    const parsed = JSON.parse(body || "{}");
    if (!parsed || typeof parsed !== "object" || !("data" in parsed)) throw new Error("no data");
    data = parsed.data;
  } catch {
    return reply(400, { error: { status: "INVALID_ARGUMENT", message: "Bad request" } });
  }
  let auth;
  const match = /^Bearer\s+(.+)$/i.exec(authorization || "");
  if (match) {
    try {
      const token = await getAuth().verifyIdToken(match[1]);
      auth = { uid: token.uid, token };
    } catch {
      return reply(401, { error: { status: "UNAUTHENTICATED", message: "Unauthenticated" } });
    }
  }
  try {
    // Calls that add or remove people stand in for the employee trigger.
    const counts = MEMBERSHIP_CALLS.has(name) && auth;
    const before = counts ? await companyOf(auth.uid) : null;
    const result = await functions[name].run({ data, auth, rawRequest: { headers: { authorization } } });
    if (counts) {
      const ids = new Set([before, await companyOf(auth.uid), data?.companyId].filter((id) => typeof id === "string" && id));
      await Promise.all([...ids].map(recountCompany)).catch((error) => console.error("recount failed", error));
    }
    return reply(200, { result: result === undefined ? null : result });
  } catch (error) {
    return errorReply(error);
  }
}

function zoned(now) {
  const parts = Object.fromEntries(new Intl.DateTimeFormat("en-CA", {
    timeZone: TIME_ZONE, year: "numeric", month: "2-digit", day: "2-digit", hour: "2-digit", minute: "2-digit", hourCycle: "h23",
  }).formatToParts(now).map((p) => [p.type, p.value]));
  return { date: `${parts.year}-${parts.month}-${parts.day}`, minutes: Number(parts.hour) * 60 + Number(parts.minute) };
}

// Keeps company.activeEmployees right, including after admins (de)activate
// people with direct writes.
async function recountHeadcounts() {
  const companies = await db.collection("companies").get();
  for (const company of companies.docs) await recountCompany(company.id);
}

// Pushes "Leave approved/rejected" once per decision. Looks back 15 minutes
// (ticks are 5 apart) and dedupes through pushLog, so overlaps are harmless.
async function pushLeaveDecisions(now) {
  const since = new Date(now.getTime() - 15 * 60 * 1000);
  const changed = await db.collectionGroup("leaves").where("updatedAt", ">=", since).get();
  for (const doc of changed.docs) {
    const leave = doc.data();
    if (!["approved", "rejected"].includes(leave.status)) continue;
    const companyId = doc.ref.parent.parent.id;
    try {
      await db.collection("pushLog").doc(`${doc.id}_${leave.status}`).create({ at: FieldValue.serverTimestamp() });
    } catch (error) {
      if (error.code === 6) continue; // already sent
      throw error;
    }
    const employee = await db.collection("companies").doc(companyId).collection("employees").doc(leave.employeeId).get();
    const token = employee.exists && employee.data().fcmToken;
    if (!token) continue;
    await getMessaging().send({
      token,
      notification: { title: `Leave ${leave.status}`, body: leave.adminNote || `Your ${leave.type} leave has been ${leave.status}.` },
    }).catch((error) => console.error("leave push failed", { code: error.code }));
  }
}

// Marks the day's no-shows absent once, in the last 15 minutes of the IST day.
async function markAbsentOnce(now) {
  const { date, minutes } = zoned(now);
  if (minutes < 23 * 60 + 45) return false;
  const marker = db.collection("system").doc("cron");
  const claimed = await db.runTransaction(async (t) => {
    const done = (await t.get(marker)).data()?.absentDate;
    if (done === date) return false;
    t.set(marker, { absentDate: date }, { merge: true });
    return true;
  });
  if (claimed) await functions.autoMarkAbsent.run({});
  return claimed;
}

async function tick(now = new Date()) {
  const steps = {
    reminders: () => functions.sendShiftReminders.run({}),
    headcount: recountHeadcounts,
    leavePushes: () => pushLeaveDecisions(now),
    absent: () => markAbsentOnce(now),
  };
  const report = {};
  for (const [name, step] of Object.entries(steps)) {
    try {
      report[name] = (await step()) ?? "ok";
    } catch (error) {
      console.error(`tick ${name} failed`, error);
      report[name] = "failed";
    }
  }
  console.log(JSON.stringify({ event: "tick", ...report }));
  return report;
}

module.exports = { handleCall, tick, recountCompany, CALLABLES };
