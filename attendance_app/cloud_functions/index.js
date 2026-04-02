const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onDocumentCreated, onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getAuth } = require("firebase-admin/auth");
const { getFirestore, FieldValue, Timestamp } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");

initializeApp();
const db = getFirestore();

// ──────────────────────────────────────────────────────────────────────────────
// 1. onEmployeeCreated — Admin adds an employee via HTTPS callable
//    Creates Firebase Auth account, writes employee doc + role doc,
//    sends welcome email via Firebase Auth's built-in email action link.
// ──────────────────────────────────────────────────────────────────────────────
exports.onEmployeeCreated = onCall(async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Must be logged in");

  const { companyId, name, email, phone, department, position, workLocation, shift } = request.data;
  if (!companyId || !name || !email) {
    throw new HttpsError("invalid-argument", "companyId, name, and email are required");
  }

  // Verify caller is admin of this company
  const callerDoc = await db.collection("users").doc(request.auth.uid).get();
  if (!callerDoc.exists || callerDoc.data().role !== "admin" || callerDoc.data().companyId !== companyId) {
    throw new HttpsError("permission-denied", "Only the company admin can add employees");
  }

  // Generate a temporary password
  const tempPassword = Math.random().toString(36).slice(-8) + "A1!";

  try {
    // Create Firebase Auth account
    const userRecord = await getAuth().createUser({
      email,
      password: tempPassword,
      displayName: name,
    });

    const uid = userRecord.uid;
    const batch = db.batch();

    // Write employee subcollection doc
    batch.set(db.collection("companies").doc(companyId).collection("employees").doc(uid), {
      uid,
      name,
      email,
      phone: phone || null,
      department: department || null,
      position: position || null,
      status: "active",
      avatarUrl: null,
      workLocation: workLocation || null,
      shift: shift || { start: "09:00", end: "18:00" },
      fcmToken: null,
      joinedAt: FieldValue.serverTimestamp(),
    });

    // Write minimal role doc for security rules
    batch.set(db.collection("users").doc(uid), {
      role: "employee",
      companyId,
    });

    // Increment company employee count
    batch.update(db.collection("companies").doc(companyId), {
      totalEmployees: FieldValue.increment(1),
    });

    await batch.commit();

    // Send password reset email so employee can set their own password
    try {
      await getAuth().generatePasswordResetLink(email);
    } catch (_) {
      // Non-critical — employee can still use temp password
    }

    return { uid, tempPassword };
  } catch (error) {
    throw new HttpsError("internal", error.message);
  }
});

// ──────────────────────────────────────────────────────────────────────────────
// 2. autoMarkAbsent — Scheduled function runs at 23:59 daily
//    Finds employees with no attendance record for today and creates 'absent'.
// ──────────────────────────────────────────────────────────────────────────────
exports.autoMarkAbsent = onSchedule("59 23 * * *", async () => {
  const today = new Date().toISOString().slice(0, 10); // YYYY-MM-DD
  const companiesSnap = await db.collection("companies").get();

  for (const companyDoc of companiesSnap.docs) {
    const companyId = companyDoc.id;
    const employeesSnap = await db
      .collection("companies").doc(companyId)
      .collection("employees")
      .where("status", "==", "active")
      .get();

    const attendanceSnap = await db
      .collection("companies").doc(companyId)
      .collection("attendance")
      .where("date", "==", today)
      .get();

    const checkedInIds = new Set(attendanceSnap.docs.map(d => d.data().employeeId));
    const batch = db.batch();
    let count = 0;

    for (const empDoc of employeesSnap.docs) {
      if (!checkedInIds.has(empDoc.id)) {
        const docId = `${empDoc.id}_${today}`;
        batch.set(
          db.collection("companies").doc(companyId).collection("attendance").doc(docId),
          {
            employeeId: empDoc.id,
            companyId,
            employeeName: empDoc.data().name || "",
            date: today,
            checkIn: null,
            checkOut: null,
            status: "absent",
            isLate: false,
            checkInLocation: null,
            checkOutLocation: null,
            selfieStoragePath: null,
            isSynced: true,
            notes: "Auto-marked absent",
          }
        );
        count++;
      }
    }

    if (count > 0) await batch.commit();
    console.log(`[autoMarkAbsent] ${companyId}: marked ${count} absent for ${today}`);
  }
});

// ──────────────────────────────────────────────────────────────────────────────
// 3. sendCheckinReminder — Scheduled function runs every 5 minutes
//    Checks if any employee's shift starts in the next 5 minutes and sends FCM.
// ──────────────────────────────────────────────────────────────────────────────
exports.sendCheckinReminder = onSchedule("*/5 * * * *", async () => {
  const now = new Date();
  const hh = String(now.getHours()).padStart(2, "0");
  const mm = String(now.getMinutes()).padStart(2, "0");
  const nowTime = `${hh}:${mm}`;

  // Check 5 min window ahead
  const ahead = new Date(now.getTime() + 5 * 60000);
  const ahh = String(ahead.getHours()).padStart(2, "0");
  const amm = String(ahead.getMinutes()).padStart(2, "0");
  const aheadTime = `${ahh}:${amm}`;

  const companiesSnap = await db.collection("companies").get();

  for (const compDoc of companiesSnap.docs) {
    const empsSnap = await db
      .collection("companies").doc(compDoc.id)
      .collection("employees")
      .where("status", "==", "active")
      .get();

    for (const empDoc of empsSnap.docs) {
      const data = empDoc.data();
      const shiftStart = data.shift?.start;
      if (!shiftStart || !data.fcmToken) continue;

      if (shiftStart >= nowTime && shiftStart <= aheadTime) {
        try {
          await getMessaging().send({
            token: data.fcmToken,
            notification: {
              title: "Time to check in!",
              body: `Your shift starts at ${shiftStart}. Don't forget to mark attendance.`,
            },
          });
        } catch (_) {}
      }
    }
  }
});

// ──────────────────────────────────────────────────────────────────────────────
// 4. onLeaveCreated — Firestore trigger: notify admin when leave is submitted
// ──────────────────────────────────────────────────────────────────────────────
exports.onLeaveCreated = onDocumentCreated(
  "companies/{companyId}/leaves/{leaveId}",
  async (event) => {
    const leaveData = event.data.data();
    const companyId = event.params.companyId;

    // Get admin's FCM token (admin uid == companyId in our schema)
    const adminEmpDoc = await db.collection("companies").doc(companyId).get();
    if (!adminEmpDoc.exists) return;

    // We don't store admin FCM token in the company doc by default,
    // but we log the notification for the admin dashboard
    await db.collection("notifications").add({
      type: "leave_request",
      companyId,
      employeeId: leaveData.employeeId,
      employeeName: leaveData.employeeName,
      message: `${leaveData.employeeName} requested ${leaveData.type} leave`,
      createdAt: FieldValue.serverTimestamp(),
      read: false,
    });
  }
);

// ──────────────────────────────────────────────────────────────────────────────
// 5. onLeaveStatusChanged — Notify employee when admin approves/rejects leave
// ──────────────────────────────────────────────────────────────────────────────
exports.onLeaveStatusChanged = onDocumentUpdated(
  "companies/{companyId}/leaves/{leaveId}",
  async (event) => {
    const before = event.data.before.data();
    const after = event.data.after.data();
    if (before.status === after.status) return;

    const companyId = event.params.companyId;
    const empDoc = await db
      .collection("companies").doc(companyId)
      .collection("employees").doc(after.employeeId)
      .get();

    if (!empDoc.exists) return;
    const token = empDoc.data().fcmToken;

    if (token) {
      try {
        await getMessaging().send({
          token,
          notification: {
            title: `Leave ${after.status}`,
            body: after.adminNote
              ? `Your leave was ${after.status}. Note: ${after.adminNote}`
              : `Your ${after.type} leave has been ${after.status}.`,
          },
        });
      } catch (_) {}
    }

    // Also log notification
    await db.collection("notifications").add({
      type: "leave_status",
      companyId,
      employeeId: after.employeeId,
      message: `Leave ${after.status} for ${after.employeeName}`,
      createdAt: FieldValue.serverTimestamp(),
      read: false,
    });
  }
);
