const { onCall, onRequest, HttpsError } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onDocumentCreated, onDocumentUpdated, onDocumentWritten } = require("firebase-functions/v2/firestore");
const { defineSecret } = require("firebase-functions/params");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue, Timestamp } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");
const { randomBytes, createHmac, timingSafeEqual } = require("crypto");

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
function location(value) {
  if (!value || !Number.isFinite(value.latitude) || !Number.isFinite(value.longitude) || Math.abs(value.latitude) > 90 || Math.abs(value.longitude) > 180) fail("invalid-argument", "A valid location is required");
  if (value.accuracy != null && (!Number.isFinite(value.accuracy) || value.accuracy < 0 || value.accuracy > 100)) fail("invalid-argument", "Location accuracy is insufficient");
  return { latitude: value.latitude, longitude: value.longitude, ...(value.accuracy != null ? { accuracy: value.accuracy } : {}) };
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

// ── Billing (Razorpay Subscriptions) ─────────────────────────────────────────
// Companies pay per employee seat. Plan, seats and billing status live on the
// company doc and are written ONLY here (checkout verification, the signed
// webhook, seat sync); Security Rules keep clients out of them.
//
// Secrets (set by the account owner, never in code):
//   firebase functions:secrets:set RAZORPAY_KEY_ID / RAZORPAY_KEY_SECRET / RAZORPAY_WEBHOOK_SECRET
// Plan ids (create the four plans in the Razorpay dashboard — amounts are the
// per-seat prices below incl. 18% GST — then put the ids in cloud_functions/.env):
//   RAZORPAY_PLAN_PRO_MONTHLY, RAZORPAY_PLAN_PRO_YEARLY,
//   RAZORPAY_PLAN_BUSINESS_MONTHLY, RAZORPAY_PLAN_BUSINESS_YEARLY

const RAZORPAY_KEY_ID = defineSecret("RAZORPAY_KEY_ID");
const RAZORPAY_KEY_SECRET = defineSecret("RAZORPAY_KEY_SECRET");
const RAZORPAY_WEBHOOK_SECRET = defineSecret("RAZORPAY_WEBHOOK_SECRET");
// Read at call time from cloud_functions/.env (loaded into process.env).
const planId = (plan, cycle) => process.env[`RAZORPAY_PLAN_${plan.toUpperCase()}_${cycle.toUpperCase()}`] || "";

// Per-seat prices in rupees, before GST. Keep in sync with lib/core/billing/pricing.dart.
const PRICES = { pro: { monthly: 39, yearly: 374 }, business: { monthly: 79, yearly: 758 } };
const FREE_EMPLOYEE_LIMIT = 5;
const LIVE_STATUSES = ["authenticated", "active", "pending"];
const BILLING_SECRETS = [RAZORPAY_KEY_ID, RAZORPAY_KEY_SECRET];

// What the company may use right now. Companies created before billing have
// no `plan` and stay unlimited ("legacy") until the owner decides otherwise.
function effectiveTier(company, now = Date.now()) {
  const plan = company?.plan;
  if (!plan) return "legacy";
  if (plan === "trial") return company.trialEndsAt?.toMillis() > now ? "trial" : "free";
  if (plan === "pro" || plan === "business") return LIVE_STATUSES.includes(company.billingStatus) ? plan : "free";
  return "free";
}

// Active + pending employees, the number a Free company is capped on.
async function headcount(companyRef) {
  const snap = await companyRef.collection("employees").where("status", "in", ["active", "pending"]).count().get();
  return snap.data().count;
}

async function assertRoomForOneMore(companyRef, company) {
  if (effectiveTier(company) !== "free") return;
  if ((await headcount(companyRef)) >= FREE_EMPLOYEE_LIMIT) {
    fail("resource-exhausted", `The Free plan includes up to ${FREE_EMPLOYEE_LIMIT} people. Ask your admin to upgrade to add more.`);
  }
}

// Razorpay REST client. Under the Functions emulator a key id starting with
// "rzp_fake_" switches to an in-memory fake so billing can be tested end to
// end without Razorpay; it can never activate in production.
function razorpay() {
  const keyId = RAZORPAY_KEY_ID.value();
  const keySecret = RAZORPAY_KEY_SECRET.value();
  if (!keyId || !keySecret) fail("failed-precondition", "Payments aren’t set up yet");
  if (process.env.FUNCTIONS_EMULATOR === "true" && keyId.startsWith("rzp_fake_")) {
    return {
      keyId, fake: true,
      createSubscription: async (body) => ({ id: `sub_fake_${randomBytes(6).toString("hex")}`, status: "created", ...body }),
      updateSubscription: async (id, body) => ({ id, ...body }),
      cancelSubscription: async (id) => ({ id, status: "active" }),
      invoices: async () => ({ items: [] }),
    };
  }
  const auth = `Basic ${Buffer.from(`${keyId}:${keySecret}`).toString("base64")}`;
  async function call(method, path, body) {
    const res = await fetch(`https://api.razorpay.com/v1${path}`, { method, headers: { Authorization: auth, "Content-Type": "application/json" }, body: body ? JSON.stringify(body) : undefined });
    const json = await res.json().catch(() => ({}));
    if (!res.ok) {
      console.error("razorpay error", { path, status: res.status, code: json?.error?.code });
      fail("internal", json?.error?.description || "The payment provider rejected the request");
    }
    return json;
  }
  return {
    keyId, fake: false,
    createSubscription: (body) => call("POST", "/subscriptions", body),
    updateSubscription: (id, body) => call("PATCH", `/subscriptions/${id}`, body),
    cancelSubscription: (id) => call("POST", `/subscriptions/${id}/cancel`, { cancel_at_cycle_end: 1 }),
    invoices: (id) => call("GET", `/invoices?subscription_id=${encodeURIComponent(id)}&count=24`),
  };
}

function hmac(secret, payload) {
  return createHmac("sha256", secret).update(payload).digest("hex");
}
function safeEqual(a, b) {
  const x = Buffer.from(String(a)), y = Buffer.from(String(b));
  return x.length === y.length && timingSafeEqual(x, y);
}

function billingInput(data) {
  const plan = data?.plan, cycle = data?.cycle, seats = Number(data?.seats);
  if (!["pro", "business"].includes(plan)) fail("invalid-argument", "Choose Pro or Business");
  if (!["monthly", "yearly"].includes(cycle)) fail("invalid-argument", "Choose monthly or yearly billing");
  if (!Number.isInteger(seats) || seats < 1 || seats > 10000) fail("invalid-argument", "Invalid number of seats");
  return { plan, cycle, seats };
}

// Admin starts (or changes) a subscription. During the trial the first charge
// is scheduled for the trial's end, so nothing is due today; the customer
// still authorises the UPI AutoPay / card mandate in Razorpay Checkout.
exports.createSubscription = onCall({ ...CALLABLE_OPTIONS, secrets: BILLING_SECRETS }, async (request) => {
  const companyId = requiredText(request.data?.companyId, "company id", 128);
  await admin(request, companyId);
  const { plan, cycle, seats } = billingInput(request.data);
  const companyRef = db.collection("companies").doc(companyId);
  const company = (await companyRef.get()).data();
  const active = await headcount(companyRef);
  if (seats < active) fail("invalid-argument", `You have ${active} people — buy at least ${active} seats`);

  const rp = razorpay();
  const plan_id = rp.fake ? `plan_fake_${plan}_${cycle}` : planId(plan, cycle);
  if (!plan_id) fail("failed-precondition", "This plan isn’t available yet");
  const trialEnd = company.plan === "trial" ? company.trialEndsAt?.toMillis() : null;
  const startAt = trialEnd && trialEnd > Date.now() + 60000 ? Math.floor(trialEnd / 1000) : undefined;

  // Changing plan on a live subscription: cancel the old one at period end.
  if (company.subscriptionId && LIVE_STATUSES.includes(company.billingStatus)) {
    await rp.cancelSubscription(company.subscriptionId).catch(() => undefined);
  }
  const sub = await rp.createSubscription({
    plan_id, quantity: seats, total_count: cycle === "monthly" ? 120 : 10, customer_notify: 1,
    ...(startAt ? { start_at: startAt } : {}),
    notes: { companyId, plan, cycle },
  });
  await companyRef.update({ pendingSubscription: { id: sub.id, plan, cycle, seats, createdAt: FieldValue.serverTimestamp() } });
  console.log(JSON.stringify({ event: "create_subscription", companyId, plan, cycle, seats, fake: rp.fake }));
  return { subscriptionId: sub.id, keyId: rp.keyId, fake: rp.fake, startsAt: startAt ? startAt * 1000 : null };
});

// Checkout success: verify Razorpay's signature and switch the company over
// straight away (the webhook confirms the same state moments later).
exports.verifySubscription = onCall({ ...CALLABLE_OPTIONS, secrets: BILLING_SECRETS }, async (request) => {
  const companyId = requiredText(request.data?.companyId, "company id", 128);
  await admin(request, companyId);
  const paymentId = requiredText(request.data?.paymentId, "payment id", 100);
  const subscriptionId = requiredText(request.data?.subscriptionId, "subscription id", 100);
  const signature = requiredText(request.data?.signature, "signature", 200);
  const companyRef = db.collection("companies").doc(companyId);
  const company = (await companyRef.get()).data();
  const pending = company.pendingSubscription;
  if (!pending || pending.id !== subscriptionId) fail("failed-precondition", "No checkout in progress for this subscription");
  // The emulator's fake Razorpay has no checkout to sign; it accepts "emulator".
  const fakeOk = razorpay().fake && signature === "emulator";
  if (!fakeOk && !safeEqual(hmac(RAZORPAY_KEY_SECRET.value(), `${paymentId}|${subscriptionId}`), signature)) fail("permission-denied", "Payment could not be verified");
  await companyRef.update({
    plan: pending.plan, cycle: pending.cycle, seats: pending.seats, billingStatus: "authenticated",
    subscriptionId, pendingSubscription: FieldValue.delete(), billingUpdatedAt: FieldValue.serverTimestamp(),
  });
  console.log(JSON.stringify({ event: "verify_subscription", companyId, subscriptionId }));
  return { plan: pending.plan, status: "authenticated" };
});

// Admin cancels: the subscription runs to the end of the paid period, then
// Razorpay's "cancelled" webhook moves the company to Free.
exports.cancelSubscription = onCall({ ...CALLABLE_OPTIONS, secrets: BILLING_SECRETS }, async (request) => {
  const companyId = requiredText(request.data?.companyId, "company id", 128);
  await admin(request, companyId);
  const companyRef = db.collection("companies").doc(companyId);
  const company = (await companyRef.get()).data();
  if (!company.subscriptionId || !LIVE_STATUSES.includes(company.billingStatus)) fail("failed-precondition", "There’s no active subscription");
  await razorpay().cancelSubscription(company.subscriptionId);
  await companyRef.update({ cancelAtPeriodEnd: true, billingUpdatedAt: FieldValue.serverTimestamp() });
  return { cancelled: true };
});

// GST invoices for the billing screen.
exports.listInvoices = onCall({ ...CALLABLE_OPTIONS, secrets: BILLING_SECRETS }, async (request) => {
  const companyId = requiredText(request.data?.companyId, "company id", 128);
  await admin(request, companyId);
  const company = (await db.collection("companies").doc(companyId).get()).data();
  if (!company.subscriptionId) return { invoices: [] };
  const { items = [] } = await razorpay().invoices(company.subscriptionId);
  return { invoices: items.map((i) => ({ id: i.id, amount: i.amount, status: i.status, date: (i.paid_at || i.issued_at || i.date) * 1000, url: i.short_url || null })) };
});

// Razorpay → us. The body is signed with the webhook secret; anything that
// doesn't verify is dropped. Idempotent: every event just restates the
// subscription's current state.
exports.razorpayWebhook = onRequest({ region: CALLABLE_OPTIONS.region, secrets: [RAZORPAY_WEBHOOK_SECRET] }, async (req, res) => {
  if (req.method !== "POST") return res.status(405).send("Method not allowed");
  const signature = req.get("X-Razorpay-Signature") || "";
  if (!req.rawBody || !safeEqual(hmac(RAZORPAY_WEBHOOK_SECRET.value(), req.rawBody), signature)) {
    console.warn("razorpay webhook: bad signature");
    return res.status(400).send("Invalid signature");
  }
  const event = req.body?.event || "";
  const sub = req.body?.payload?.subscription?.entity;
  if (!event.startsWith("subscription.") || !sub?.id) return res.status(200).send("ignored");
  const companyId = sub.notes?.companyId;
  if (!companyId) return res.status(200).send("no company");
  const companyRef = db.collection("companies").doc(companyId);
  await db.runTransaction(async (transaction) => {
    const snap = await transaction.get(companyRef);
    if (!snap.exists) return;
    const company = snap.data();
    // Only the company's current (or just-created) subscription may change it.
    if (sub.id !== company.subscriptionId && sub.id !== company.pendingSubscription?.id) return;
    const live = LIVE_STATUSES.includes(sub.status);
    const update = { billingStatus: sub.status, billingUpdatedAt: FieldValue.serverTimestamp() };
    if (live) {
      Object.assign(update, {
        plan: sub.notes.plan, cycle: sub.notes.cycle, seats: Number(sub.quantity) || company.seats || 1, subscriptionId: sub.id,
        ...(sub.current_end ? { currentPeriodEnd: Timestamp.fromMillis(sub.current_end * 1000) } : {}),
      });
      if (company.pendingSubscription?.id === sub.id) update.pendingSubscription = FieldValue.delete();
    } else if (["halted", "cancelled", "completed", "expired"].includes(sub.status) && sub.id === company.subscriptionId) {
      Object.assign(update, { plan: "free", cancelAtPeriodEnd: FieldValue.delete() });
    }
    transaction.update(companyRef, update);
  });
  console.log(JSON.stringify({ event: "razorpay_webhook", type: event, companyId, status: sub.status }));
  return res.status(200).send("ok");
});

// Keeps company.activeEmployees current (Rules use it to hold Free companies
// to 5 people) and grows a paid subscription's seats when the team outgrows
// them — billed from the next cycle, as the billing screen says.
exports.onEmployeeWritten = onDocumentWritten({ document: "companies/{companyId}/employees/{employeeId}", secrets: BILLING_SECRETS }, async (event) => {
  const before = event.data.before.data()?.status, after = event.data.after.data()?.status;
  const counted = (s) => s === "active" || s === "pending";
  if (counted(before) === counted(after)) return;
  const companyRef = db.collection("companies").doc(event.params.companyId);
  const count = await headcount(companyRef);
  const company = (await companyRef.get()).data();
  if (!company) return;
  await companyRef.update({ activeEmployees: count });
  if (["pro", "business"].includes(effectiveTier(company)) && company.subscriptionId && count > (company.seats || 0)) {
    try {
      await razorpay().updateSubscription(company.subscriptionId, { quantity: count, schedule_change_at: "cycle_end" });
      await companyRef.update({ seats: count });
    } catch (error) {
      console.error("seat sync failed", { companyId: event.params.companyId, message: error.message });
    }
  }
});

// ── Onboarding ────────────────────────────────────────────────────────────────
// Companies, joins and invites are written ONLY here (admin SDK); Security
// Rules give clients no way to create them. Billing fields set at signup
// (plan, trialEndsAt) are likewise server-owned.

const TRIAL_DAYS = 14;
const CODE_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
const MAX_IMPORT_ROWS = 500;
const MAX_SITES_PER_EMPLOYEE = 10;

function shortCode(length = 6) {
  const bytes = randomBytes(length);
  return Array.from(bytes, (b) => CODE_ALPHABET[b % CODE_ALPHABET.length]).join("");
}

// A join code nobody else holds (codes/{code} is the registry).
async function freshCode(transaction) {
  for (let i = 0; i < 8; i++) {
    const code = shortCode();
    if (!(await transaction.get(db.collection("codes").doc(code))).exists) return code;
  }
  fail("internal", "Could not allocate a join code");
}

// Indian numbers by default: "98450 12345" → "+919845012345".
function normalizePhone(value) {
  if (typeof value !== "string" && typeof value !== "number") return null;
  let digits = String(value).replace(/[\s\-().]/g, "");
  if (digits.startsWith("+")) return /^\+[1-9]\d{7,14}$/.test(digits) ? digits : null;
  if (/^0\d{10}$/.test(digits)) digits = digits.slice(1);
  if (/^[6-9]\d{9}$/.test(digits)) return `+91${digits}`;
  if (/^91[6-9]\d{9}$/.test(digits)) return `+${digits}`;
  return null;
}

function zoneOf(site) {
  return { latitude: site.latitude, longitude: site.longitude, radius: site.radius, address: site.address || site.name };
}

function siteInput(value) {
  const loc = location(value);
  const radius = Number(value.radius);
  if (!Number.isFinite(radius) || radius < 10 || radius > 5000) fail("invalid-argument", "Invalid zone radius");
  return {
    name: requiredText(value.name ?? "Head office", "location name", 100),
    address: optionalText(value.address, "address", 500),
    latitude: loc.latitude, longitude: loc.longitude, radius, isMain: true,
  };
}

function shiftInput(start, end, fallback = { start: "09:00", end: "18:00" }) {
  const shift = { start: start || fallback.start, end: end || fallback.end };
  if (!validTime(shift.start) || !validTime(shift.end) || shift.start >= shift.end) fail("invalid-argument", "Invalid shift");
  return shift;
}

// Self-serve company signup: the signed-in (email) user becomes the admin of a
// new company on a free trial, with its main site and an employee join code.
exports.registerCompany = onCall(CALLABLE_OPTIONS, async (request) => {
  if (!request.auth) fail("unauthenticated", "Sign-in is required");
  const uid = request.auth.uid;
  const email = requiredText(request.auth.token.email, "account email", 320).toLowerCase();
  const companyName = requiredText(request.data?.companyName, "company name", 120);
  const adminName = requiredText(request.data?.adminName, "your name", 200);
  const site = siteInput(request.data?.location);
  const shift = shiftInput(request.data?.shiftStart, request.data?.shiftEnd);
  const teamSize = optionalText(request.data?.teamSize, "team size", 20);

  const companyRef = db.collection("companies").doc();
  const roleRef = db.collection("users").doc(uid);
  const siteRef = companyRef.collection("locations").doc();
  const code = await db.runTransaction(async (transaction) => {
    if ((await transaction.get(roleRef)).exists) fail("already-exists", "This account already belongs to a company");
    const joinCode = await freshCode(transaction);
    transaction.set(companyRef, {
      companyId: companyRef.id, companyName, adminId: uid, adminName, adminEmail: email,
      phone: null, address: site.address, status: "active", employeeCode: joinCode,
      createdBy: uid, createdAt: FieldValue.serverTimestamp(), totalEmployees: 0, activeEmployees: 0, teamSize,
      plan: "trial", trialEndsAt: Timestamp.fromMillis(Date.now() + TRIAL_DAYS * 86400000),
      settings: { defaultRadius: site.radius, defaultShiftStart: shift.start, defaultShiftEnd: shift.end, approveJoiners: false },
    });
    transaction.set(siteRef, { ...site, createdAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp() });
    transaction.set(db.collection("codes").doc(joinCode), { companyId: companyRef.id, type: "employee", createdAt: FieldValue.serverTimestamp() });
    transaction.set(roleRef, { role: "admin", companyId: companyRef.id, viaCode: "self-serve" });
    return joinCode;
  });
  console.log(JSON.stringify({ event: "register_company", companyId: companyRef.id, uid }));
  return { companyId: companyRef.id, employeeCode: code };
});

// An unprovisioned, signed-in user joins a company: by a phone invite the
// admin created (matched on the caller's verified phone number), or by the
// company's join code (typed or scanned from its QR). Code joiners wait for
// approval when the company asks for it; invited people are pre-approved.
exports.claimJoin = onCall(CALLABLE_OPTIONS, async (request) => {
  if (!request.auth) fail("unauthenticated", "Sign-in is required");
  const uid = request.auth.uid;
  const phone = request.auth.token.phone_number || null;
  const email = request.auth.token.email ? String(request.auth.token.email).toLowerCase() : null;
  const code = request.data?.code ? requiredText(request.data.code, "code", 20).toUpperCase() : null;
  const roleRef = db.collection("users").doc(uid);

  const result = await db.runTransaction(async (transaction) => {
    if ((await transaction.get(roleRef)).exists) fail("already-exists", "You’re already part of a company");
    const inviteRef = phone ? db.collection("invites").doc(phone) : null;
    const invite = inviteRef ? await transaction.get(inviteRef) : null;

    let companyId;
    if (code) {
      const codeDoc = await transaction.get(db.collection("codes").doc(code));
      if (!codeDoc.exists || codeDoc.data().type !== "employee") fail("not-found", "That code isn’t valid. Check it with your admin.");
      companyId = codeDoc.data().companyId;
    } else if (invite?.exists) {
      companyId = invite.data().companyId;
    } else {
      fail("not-found", "We couldn’t find an invite for this number. Enter your company code instead.");
    }
    const companyRef = db.collection("companies").doc(companyId);
    const company = await transaction.get(companyRef);
    if (!company.exists || (company.data().status || "active") !== "active") fail("failed-precondition", "This company isn’t accepting new members right now");
    await assertRoomForOneMore(companyRef, company.data());

    // An invite counts only for the company being joined.
    const inv = invite?.exists && invite.data().companyId === companyId ? invite.data() : null;
    const name = inv?.name || requiredText(request.data?.name, "your name", 200);
    const settings = company.data().settings || {};

    let locationIds = (inv?.locationIds || []).slice(0, MAX_SITES_PER_EMPLOYEE);
    let primaryId = inv?.primaryLocationId || locationIds[0] || null;
    let primary = null;
    if (primaryId) {
      const doc = await transaction.get(companyRef.collection("locations").doc(primaryId));
      primary = doc.exists ? doc.data() : null;
    }
    if (!primary) {
      const main = await transaction.get(companyRef.collection("locations").where("isMain", "==", true).limit(1));
      if (!main.empty) {
        primary = main.docs[0].data();
        primaryId = main.docs[0].id;
        if (!locationIds.includes(primaryId)) locationIds = [primaryId, ...locationIds].slice(0, MAX_SITES_PER_EMPLOYEE);
      } else {
        primaryId = null;
        locationIds = [];
      }
    }

    const status = inv || !settings.approveJoiners ? "active" : "pending";
    transaction.set(companyRef.collection("employees").doc(uid), {
      uid, name, email: email || "", phone, department: inv?.department || null, position: inv?.position || null,
      status, avatarUrl: null, workLocation: primary ? zoneOf(primary) : null,
      locationIds, primaryLocationId: primaryId,
      shift: inv?.shift || { start: settings.defaultShiftStart || "09:00", end: settings.defaultShiftEnd || "18:00" },
      fcmToken: null, joinedAt: FieldValue.serverTimestamp(),
    });
    transaction.set(roleRef, { role: "employee", companyId, viaCode: code || "invite" });
    transaction.update(companyRef, { totalEmployees: FieldValue.increment(1) });
    if (inv) transaction.delete(inviteRef);
    return { companyId, status };
  });
  console.log(JSON.stringify({ event: "claim_join", uid, companyId: result.companyId, status: result.status, via: code ? "code" : "invite" }));
  return result;
});

// Admin invites people by phone — one from a form or up to 500 from an
// uploaded sheet. Each row becomes invites/{E.164 phone}; the person joins by
// signing in with that number. Rows are validated independently so one bad
// row never sinks the rest.
exports.importEmployees = onCall(CALLABLE_OPTIONS, async (request) => {
  const companyId = requiredText(request.data?.companyId, "company id", 128);
  const user = await admin(request, companyId);
  const rows = request.data?.rows;
  if (!Array.isArray(rows) || rows.length === 0 || rows.length > MAX_IMPORT_ROWS) fail("invalid-argument", `Send between 1 and ${MAX_IMPORT_ROWS} people`);

  const companyRef = db.collection("companies").doc(companyId);
  const company = (await companyRef.get()).data() || {};
  const settings = company.settings || {};
  const sites = (await companyRef.collection("locations").get()).docs.map((d) => ({ id: d.id, ...d.data() }));
  const byName = new Map(sites.map((s) => [s.name.trim().toLowerCase(), s]));
  const main = sites.find((s) => s.isMain) || sites[0] || null;
  const fallbackShift = { start: settings.defaultShiftStart || "09:00", end: settings.defaultShiftEnd || "18:00" };

  // A Free company can only invite up to its 5-person limit.
  let room = effectiveTier(company) === "free" ? Math.max(0, FREE_EMPLOYEE_LIMIT - (await headcount(companyRef))) : Infinity;
  const errors = [];
  const valid = [];
  const seen = new Set();
  rows.forEach((row, index) => {
    try {
      const name = requiredText(row?.name, "name", 200);
      const phone = normalizePhone(row?.phone);
      if (!phone) fail("invalid-argument", "Invalid phone number");
      if (seen.has(phone)) fail("invalid-argument", "Phone number repeated in this list");
      seen.add(phone);
      const names = String(row?.location ?? "").split(/[;|]/).map((s) => s.trim()).filter(Boolean);
      const picked = [];
      for (const n of names) {
        const site = byName.get(n.toLowerCase());
        if (!site) fail("invalid-argument", `Unknown location “${n}”`);
        if (!picked.includes(site.id)) picked.push(site.id);
      }
      if (!picked.length && main) picked.push(main.id);
      if (picked.length > MAX_SITES_PER_EMPLOYEE) fail("invalid-argument", "More than 10 locations");
      valid.push({
        index, phone,
        invite: {
          companyId, name, phone,
          department: optionalText(row?.department, "department"),
          position: optionalText(row?.position, "position"),
          locationIds: picked, primaryLocationId: picked[0] || null,
          shift: shiftInput(row?.shiftStart, row?.shiftEnd, fallbackShift),
          invitedBy: user.uid, createdAt: FieldValue.serverTimestamp(),
        },
      });
    } catch (error) {
      errors.push({ row: index, message: error.message || "Invalid row" });
    }
  });

  let created = 0, updated = 0;
  for (let i = 0; i < valid.length; i += 100) {
    const chunk = valid.slice(i, i + 100);
    const refs = chunk.map((v) => db.collection("invites").doc(v.phone));
    const existing = await db.getAll(...refs);
    const members = await Promise.all(chunk.map((v) => companyRef.collection("employees").where("phone", "==", v.phone).limit(1).get()));
    const batch = db.batch();
    chunk.forEach((v, k) => {
      if (!members[k].empty) { errors.push({ row: v.index, message: "Already on your team" }); return; }
      const other = existing[k].exists && existing[k].data().companyId !== companyId;
      if (other) { errors.push({ row: v.index, message: "Invited by another company" }); return; }
      if (!existing[k].exists && room <= 0) { errors.push({ row: v.index, message: `The Free plan includes up to ${FREE_EMPLOYEE_LIMIT} people — upgrade to invite more` }); return; }
      if (!existing[k].exists) room--;
      if (existing[k].exists) updated++; else created++;
      batch.set(refs[k], v.invite);
    });
    await batch.commit();
  }
  errors.sort((a, b) => a.row - b.row);
  console.log(JSON.stringify({ event: "import_employees", companyId, created, updated, errors: errors.length }));
  return { created, updated, errors };
});

// Admin replaces the company's join code (e.g. after it leaked). The old code
// stops working immediately; existing members are unaffected.
exports.resetJoinCode = onCall(CALLABLE_OPTIONS, async (request) => {
  const companyId = requiredText(request.data?.companyId, "company id", 128);
  await admin(request, companyId);
  const companyRef = db.collection("companies").doc(companyId);
  const code = await db.runTransaction(async (transaction) => {
    const company = await transaction.get(companyRef);
    const old = company.data()?.employeeCode;
    const next = await freshCode(transaction);
    transaction.set(db.collection("codes").doc(next), { companyId, type: "employee", createdAt: FieldValue.serverTimestamp() });
    if (old) transaction.delete(db.collection("codes").doc(old));
    transaction.update(companyRef, { employeeCode: next });
    return next;
  });
  return { employeeCode: code };
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
