const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onDocumentCreated, onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getAuth } = require("firebase-admin/auth");
const { getFirestore, FieldValue, Timestamp } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");
const { randomBytes } = require("crypto");

initializeApp();
const db = getFirestore();
const TIME_ZONE = process.env.ATTENDANCE_TIME_ZONE || "Asia/Kolkata";
const CALLABLE_OPTIONS = { region: process.env.FUNCTION_REGION || "asia-south1" };

function fail(code, message) { throw new HttpsError(code, message); }
function requiredText(value, name, max = 200) {
  if (typeof value !== "string" || !(value = value.trim()) || value.length > max) fail("invalid-argument", `Invalid ${name}`);
  return value;
}
function optionalText(value, name, max = 200) {
  if (value == null || value === "") return null;
  return requiredText(value, name, max);
}
function validTime(value) { return typeof value === "string" && /^([01]\d|2[0-3]):[0-5]\d$/.test(value); }
function toMinutes(value) { if (!validTime(value)) return null; const [h, m] = value.split(":").map(Number); return h * 60 + m; }
async function sendPush(token, title, body) {
  await getMessaging().send({ token, notification: { title, body } }).catch((error) => console.error("push failed", { code: error.code }));
}
function dateForZone(now = new Date()) {
  const parts = new Intl.DateTimeFormat("en-CA", { timeZone: TIME_ZONE, year: "numeric", month: "2-digit", day: "2-digit" }).formatToParts(now);
  const get = (type) => parts.find((part) => part.type === type).value;
  return `${get("year")}-${get("month")}-${get("day")}`;
}
function timeForZone(now = new Date()) {
  return new Intl.DateTimeFormat("en-GB", { timeZone: TIME_ZONE, hour: "2-digit", minute: "2-digit", hourCycle: "h23" }).format(now);
}
function distanceMeters(a, b) {
  const rad = (n) => (n * Math.PI) / 180;
  const dLat = rad(b.latitude - a.latitude), dLng = rad(b.longitude - a.longitude);
  const x = Math.sin(dLat / 2) ** 2 + Math.cos(rad(a.latitude)) * Math.cos(rad(b.latitude)) * Math.sin(dLng / 2) ** 2;
  return 6371000 * 2 * Math.atan2(Math.sqrt(x), Math.sqrt(1 - x));
}
function location(value) {
  if (!value || !Number.isFinite(value.latitude) || !Number.isFinite(value.longitude) || Math.abs(value.latitude) > 90 || Math.abs(value.longitude) > 180) fail("invalid-argument", "A valid location is required");
  if (value.accuracy != null && (!Number.isFinite(value.accuracy) || value.accuracy < 0 || value.accuracy > 100)) fail("invalid-argument", "Location accuracy is insufficient");
  return { latitude: value.latitude, longitude: value.longitude, ...(value.accuracy != null ? { accuracy: value.accuracy } : {}) };
}
// Accepts an offline-captured instant (epoch ms or ISO string) and rejects
// times that are in the future or unreasonably old (stale queue).
function capturedInstant(value) {
  const ms = typeof value === "number" ? value : Date.parse(value);
  if (!Number.isFinite(ms)) fail("invalid-argument", "Invalid capture time");
  const now = Date.now();
  if (ms > now + 5 * 60 * 1000) fail("invalid-argument", "Capture time is in the future");
  if (ms < now - 7 * 24 * 60 * 60 * 1000) fail("invalid-argument", "Capture time is too old to sync");
  return new Date(ms);
}
async function caller(request) {
  if (!request.auth) fail("unauthenticated", "Sign-in is required");
  const role = await db.collection("users").doc(request.auth.uid).get();
  if (!role.exists) fail("permission-denied", "Your account is not provisioned");
  return { uid: request.auth.uid, ...role.data() };
}
async function admin(request, companyId) {
  const user = await caller(request);
  if (user.role !== "admin" || user.companyId !== companyId) fail("permission-denied", "Administrator access is required");
  return user;
}

exports.registerCompany = onCall(CALLABLE_OPTIONS, async (request) => {
  const user = await caller(request).catch((error) => { if (error.code === "permission-denied") return { uid: request.auth.uid }; throw error; });
  const companyName = requiredText(request.data?.companyName, "company name");
  const adminName = requiredText(request.data?.adminName, "administrator name");
  const email = requiredText(request.auth.token.email, "authenticated email", 320);
  const companyRef = db.collection("companies").doc(user.uid);
  await db.runTransaction(async (transaction) => {
    if ((await transaction.get(companyRef)).exists || (await transaction.get(db.collection("users").doc(user.uid))).exists) fail("already-exists", "This account is already registered");
    transaction.set(companyRef, { companyId: user.uid, companyName, adminId: user.uid, adminName, adminEmail: email, phone: null, createdAt: FieldValue.serverTimestamp(), totalEmployees: 0, settings: { defaultRadius: 100, defaultShiftStart: "09:00", defaultShiftEnd: "18:00" } });
    transaction.set(db.collection("users").doc(user.uid), { role: "admin", companyId: user.uid });
  });
  return { companyId: user.uid };
});

exports.onEmployeeCreated = onCall(CALLABLE_OPTIONS, async (request) => {
  const companyId = requiredText(request.data?.companyId, "company id", 128);
  await admin(request, companyId);
  const name = requiredText(request.data?.name, "name");
  const email = requiredText(request.data?.email, "email", 320).toLowerCase();
  if (!/^\S+@\S+\.\S+$/.test(email)) fail("invalid-argument", "Invalid email");
  const shift = request.data?.shift || { start: "09:00", end: "18:00" };
  if (!validTime(shift.start) || !validTime(shift.end) || shift.start >= shift.end) fail("invalid-argument", "Invalid shift");
  const workLocation = request.data?.workLocation == null ? null : { ...location(request.data.workLocation), radius: Number(request.data.workLocation.radius) };
  if (workLocation && (!Number.isFinite(workLocation.radius) || workLocation.radius < 10 || workLocation.radius > 5000)) fail("invalid-argument", "Invalid work-location radius");
  const password = `${randomBytes(24).toString("base64url")}Aa1!`;
  let authUser;
  try { authUser = await getAuth().createUser({ email, password, displayName: name }); }
  catch (error) { console.error("employee creation failed", { companyId, code: error.code }); fail(error.code === "auth/email-already-exists" ? "already-exists" : "internal", "Unable to create employee account"); }
  try {
    const batch = db.batch();
    batch.set(db.collection("companies").doc(companyId).collection("employees").doc(authUser.uid), { uid: authUser.uid, name, email, phone: optionalText(request.data?.phone, "phone", 40), department: optionalText(request.data?.department, "department"), position: optionalText(request.data?.position, "position"), status: "active", avatarUrl: null, workLocation, shift, fcmToken: null, joinedAt: FieldValue.serverTimestamp() });
    batch.set(db.collection("users").doc(authUser.uid), { role: "employee", companyId });
    batch.update(db.collection("companies").doc(companyId), { totalEmployees: FieldValue.increment(1) });
    await batch.commit();
    await getAuth().generatePasswordResetLink(email);
    return { uid: authUser.uid };
  } catch (error) {
    await getAuth().deleteUser(authUser.uid).catch(() => undefined);
    console.error("employee provisioning rollback", { companyId, uid: authUser.uid, code: error.code });
    fail("internal", "Unable to provision employee");
  }
});

exports.updateEmployee = onCall(CALLABLE_OPTIONS, async (request) => {
  const companyId = requiredText(request.data?.companyId, "company id", 128);
  await admin(request, companyId);
  const employeeId = requiredText(request.data?.employeeId, "employee id", 128);
  const shift = request.data?.shift;
  if (!shift || !validTime(shift.start) || !validTime(shift.end) || shift.start >= shift.end) fail("invalid-argument", "Invalid shift");
  const workLocation = request.data?.workLocation == null ? null : { ...location(request.data.workLocation), radius: Number(request.data.workLocation.radius) };
  if (workLocation && (!Number.isFinite(workLocation.radius) || workLocation.radius < 10 || workLocation.radius > 5000)) fail("invalid-argument", "Invalid work-location radius");
  await db.collection("companies").doc(companyId).collection("employees").doc(employeeId).update({ name: requiredText(request.data?.name, "name"), phone: optionalText(request.data?.phone, "phone", 40), department: optionalText(request.data?.department, "department"), position: optionalText(request.data?.position, "position"), shift, workLocation, updatedAt: FieldValue.serverTimestamp() });
  return { updated: true };
});

exports.onCheckIn = onCall(CALLABLE_OPTIONS, async (request) => {
  const user = await caller(request); const companyId = requiredText(request.data?.companyId, "company id", 128);
  if (user.role !== "employee" || user.companyId !== companyId) fail("permission-denied", "Employee access is required");
  const currentLocation = location(request.data?.location); const now = new Date(); const date = dateForZone(now); const ref = db.collection("companies").doc(companyId).collection("attendance").doc(`${user.uid}_${date}`);
  await db.runTransaction(async (transaction) => {
    const employee = await transaction.get(db.collection("companies").doc(companyId).collection("employees").doc(user.uid));
    if (!employee.exists || employee.data().status !== "active") fail("permission-denied", "Your employee account is inactive");
    const assigned = employee.data().workLocation;
    if (!assigned) fail("failed-precondition", "No work location is assigned");
    const allowed = Number(assigned.radius) || 100;
    if (distanceMeters(currentLocation, assigned) > allowed) fail("permission-denied", "You are outside the work location radius");
    if ((await transaction.get(ref)).exists) fail("already-exists", "You have already checked in today");
    const [hour, minute] = (employee.data().shift?.start || "09:00").split(":").map(Number);
    const [nowHour, nowMinute] = timeForZone(now).split(":").map(Number);
    const isLate = nowHour * 60 + nowMinute > hour * 60 + minute + 15;
    const selfieStoragePath = request.data?.selfieStoragePath;
    if (selfieStoragePath != null && (typeof selfieStoragePath !== "string" || !selfieStoragePath.startsWith(`selfies/${companyId}/${user.uid}/`))) fail("invalid-argument", "Invalid selfie path");
    transaction.set(ref, { employeeId: user.uid, companyId, employeeName: employee.data().name, date, checkIn: Timestamp.fromDate(now), checkOut: null, status: isLate ? "late" : "present", isLate, checkInLocation: currentLocation, checkOutLocation: null, selfieStoragePath: selfieStoragePath || null, isSynced: true, notes: null });
  });
  return { attendanceId: ref.id };
});

exports.onCheckOut = onCall(CALLABLE_OPTIONS, async (request) => {
  const user = await caller(request); const companyId = requiredText(request.data?.companyId, "company id", 128);
  if (user.role !== "employee" || user.companyId !== companyId) fail("permission-denied", "Employee access is required");
  const currentLocation = location(request.data?.location); const ref = db.collection("companies").doc(companyId).collection("attendance").doc(`${user.uid}_${dateForZone()}`);
  await db.runTransaction(async (transaction) => {
    const record = await transaction.get(ref);
    if (!record.exists || !record.data().checkIn) fail("failed-precondition", "Check in before checking out");
    if (record.data().checkOut) fail("already-exists", "You have already checked out today");
    transaction.update(ref, { checkOut: FieldValue.serverTimestamp(), checkOutLocation: currentLocation });
  });
  return { attendanceId: ref.id };
});

exports.autoMarkAbsent = onSchedule({ schedule: "59 23 * * *", timeZone: TIME_ZONE, region: CALLABLE_OPTIONS.region }, async () => {
  const date = dateForZone(); const companies = await db.collection("companies").get();
  for (const company of companies.docs) {
    const employees = await company.ref.collection("employees").where("status", "==", "active").get();
    const writes = employees.docs.map((employee) => company.ref.collection("attendance").doc(`${employee.id}_${date}`).create({ employeeId: employee.id, companyId: company.id, employeeName: employee.data().name || "", date, checkIn: null, checkOut: null, status: "absent", isLate: false, checkInLocation: null, checkOutLocation: null, selfieStoragePath: null, isSynced: true, notes: "Auto-marked absent" }).catch((error) => { if (error.code !== 6) throw error; }));
    await Promise.all(writes); console.log(JSON.stringify({ event: "auto_mark_absent", companyId: company.id, date, employees: employees.size }));
  }
});

exports.onLeaveCreated = onDocumentCreated("companies/{companyId}/leaves/{leaveId}", async (event) => {
  const leave = event.data.data();
  await db.collection("notifications").add({ type: "leave_request", companyId: event.params.companyId, employeeId: leave.employeeId, employeeName: leave.employeeName, message: `${leave.employeeName} requested ${leave.type} leave`, createdAt: FieldValue.serverTimestamp(), read: false });
});
exports.onLeaveStatusChanged = onDocumentUpdated("companies/{companyId}/leaves/{leaveId}", async (event) => {
  const before = event.data.before.data(), after = event.data.after.data(); if (before.status === after.status) return;
  const employee = await db.collection("companies").doc(event.params.companyId).collection("employees").doc(after.employeeId).get();
  if (employee.exists && employee.data().fcmToken) await getMessaging().send({ token: employee.data().fcmToken, notification: { title: `Leave ${after.status}`, body: after.adminNote || `Your ${after.type} leave has been ${after.status}.` } }).catch((error) => console.error("leave notification failed", { code: error.code }));
  await db.collection("notifications").add({ type: "leave_status", companyId: event.params.companyId, employeeId: after.employeeId, message: `Leave ${after.status} for ${after.employeeName}`, createdAt: FieldValue.serverTimestamp(), read: false });
});

// Replays attendance events captured while the device was offline. Each event
// is validated server-side against the stored work location and the captured
// instant, so geofence and late-status remain server-authoritative even though
// the action happened earlier on the device. Per-event results let the client
// clear exactly what synced and retry the rest.
exports.syncOfflineAttendance = onCall(CALLABLE_OPTIONS, async (request) => {
  const user = await caller(request);
  const companyId = requiredText(request.data?.companyId, "company id", 128);
  if (user.role !== "employee" || user.companyId !== companyId) fail("permission-denied", "Employee access is required");
  const events = request.data?.events;
  if (!Array.isArray(events) || events.length === 0 || events.length > 100) fail("invalid-argument", "A batch of 1-100 events is required");

  const employeeRef = db.collection("companies").doc(companyId).collection("employees").doc(user.uid);
  const employeeSnap = await employeeRef.get();
  if (!employeeSnap.exists || employeeSnap.data().status !== "active") fail("permission-denied", "Your employee account is inactive");
  const employee = employeeSnap.data();
  const assigned = employee.workLocation;
  const shiftStart = employee.shift?.start || "09:00";

  const results = [];
  for (const event of events) {
    const clientId = typeof event?.clientId === "string" ? event.clientId : null;
    try {
      const type = event?.type;
      if (type !== "checkIn" && type !== "checkOut") fail("invalid-argument", "Invalid event type");
      const capturedAt = capturedInstant(event?.capturedAt);
      const currentLocation = location(event?.location);
      const date = dateForZone(capturedAt);
      const ref = db.collection("companies").doc(companyId).collection("attendance").doc(`${user.uid}_${date}`);
      const outcome = await db.runTransaction(async (transaction) => {
        const existing = await transaction.get(ref);
        if (type === "checkIn") {
          if (!assigned) fail("failed-precondition", "No work location is assigned");
          if (distanceMeters(currentLocation, assigned) > (Number(assigned.radius) || 100)) fail("permission-denied", "Outside the work location radius");
          if (existing.exists) return "duplicate";
          const [hour, minute] = shiftStart.split(":").map(Number);
          const [capturedHour, capturedMinute] = timeForZone(capturedAt).split(":").map(Number);
          const isLate = capturedHour * 60 + capturedMinute > hour * 60 + minute + 15;
          transaction.set(ref, { employeeId: user.uid, companyId, employeeName: employee.name, date, checkIn: Timestamp.fromDate(capturedAt), checkOut: null, status: isLate ? "late" : "present", isLate, checkInLocation: currentLocation, checkOutLocation: null, selfieStoragePath: null, isSynced: true, notes: "Synced from offline" });
          return "created";
        }
        if (!existing.exists || !existing.data().checkIn) fail("failed-precondition", "No matching check-in to check out from");
        if (existing.data().checkOut) return "duplicate";
        transaction.update(ref, { checkOut: Timestamp.fromDate(capturedAt), checkOutLocation: currentLocation });
        return "updated";
      });
      results.push({ clientId, status: outcome });
    } catch (error) {
      // A single bad event never fails the batch; the client keeps/retries it.
      results.push({ clientId, status: "error", code: error.code || "internal", message: error.message || "Sync failed" });
    }
  }
  console.log(JSON.stringify({ event: "sync_offline_attendance", companyId, uid: user.uid, count: events.length }));
  return { results };
});

// Fires every 5 minutes and nudges employees: a check-in reminder in the 5-min
// window before shift start (when no check-in exists yet) and a check-out
// reminder 30-35 min after shift end (when checked in but not out). The narrow
// windows keep each reminder to roughly one send per day without per-employee
// dynamic schedules.
exports.sendShiftReminders = onSchedule({ schedule: "*/5 * * * *", timeZone: TIME_ZONE, region: CALLABLE_OPTIONS.region }, async () => {
  const now = new Date();
  const date = dateForZone(now);
  const [nowHour, nowMinute] = timeForZone(now).split(":").map(Number);
  const nowMinutes = nowHour * 60 + nowMinute;
  const companies = await db.collection("companies").get();
  for (const company of companies.docs) {
    const employees = await company.ref.collection("employees").where("status", "==", "active").get();
    for (const employee of employees.docs) {
      const data = employee.data();
      if (!data.fcmToken) continue;
      const startMinutes = toMinutes(data.shift?.start);
      const endMinutes = toMinutes(data.shift?.end);
      const attendanceRef = company.ref.collection("attendance").doc(`${employee.id}_${date}`);

      if (startMinutes != null && nowMinutes >= startMinutes - 5 && nowMinutes < startMinutes) {
        const attendance = await attendanceRef.get();
        if (!attendance.exists || !attendance.data().checkIn) {
          await sendPush(data.fcmToken, "Time to check in", `Your shift starts at ${data.shift.start}. Don't forget to check in.`);
        }
      }

      if (endMinutes != null && nowMinutes >= endMinutes + 30 && nowMinutes < endMinutes + 35) {
        const attendance = await attendanceRef.get();
        if (attendance.exists && attendance.data().checkIn && !attendance.data().checkOut) {
          await sendPush(data.fcmToken, "Don't forget to check out", `Your shift ended at ${data.shift.end}. Please check out to record your hours.`);
        }
      }
    }
  }
});
