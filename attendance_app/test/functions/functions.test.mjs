// End-to-end tests for the onboarding Cloud Functions against the local
// emulators (auth, firestore, functions). Run from attendance_app/ with the
// emulators up:
//   firebase emulators:exec --only auth,firestore,functions --project trackin-df4d8 \
//     "node test/functions/functions.test.mjs"
// Uses fresh emails / phone numbers each run, so it never needs a wipe.

import { createHmac } from 'node:crypto';

const PROJECT = process.env.GCLOUD_PROJECT || 'trackin-df4d8';
const AUTH = 'http://127.0.0.1:9099';
const FS = `http://127.0.0.1:8085/v1/projects/${PROJECT}/databases/(default)/documents`;
const FN = `http://127.0.0.1:5001/${PROJECT}/asia-south1`;
const RUN = Date.now().toString().slice(-6);
let pass = 0, failN = 0;

async function t(name, fn) {
  try { await fn(); pass++; console.log('  ok   ', name); }
  catch (e) { failN++; console.log('  FAIL ', name, '-', e.message); }
}
function eq(a, b, what = 'value') { if (JSON.stringify(a) !== JSON.stringify(b)) throw new Error(`${what}: expected ${JSON.stringify(b)}, got ${JSON.stringify(a)}`); }

async function post(url, body, token) {
  const res = await fetch(url, { method: 'POST', headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}) }, body: JSON.stringify(body) });
  return res.json();
}
async function emailUser(tag) {
  const r = await post(`${AUTH}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake`, { email: `${tag}-${RUN}@test.dev`, password: 'secret-pass-1', returnSecureToken: true });
  return { token: r.idToken, uid: r.localId };
}
let phoneSeq = 0;
function freshPhone() { return `+9198${RUN}${String(phoneSeq++).padStart(2, '0')}`; }
async function phoneUser(phone) {
  const { sessionInfo } = await post(`${AUTH}/identitytoolkit.googleapis.com/v1/accounts:sendVerificationCode?key=fake`, { phoneNumber: phone });
  const codes = (await (await fetch(`${AUTH}/emulator/v1/projects/${PROJECT}/verificationCodes`)).json()).verificationCodes;
  const code = codes.filter((c) => c.sessionInfo === sessionInfo).pop().code;
  const r = await post(`${AUTH}/identitytoolkit.googleapis.com/v1/accounts:signInWithPhoneNumber?key=fake`, { sessionInfo, code });
  return { token: r.idToken, uid: r.localId, phone };
}
async function call(name, data, user) {
  const r = await post(`${FN}/${name}`, { data }, user?.token);
  if (r.error) { const e = new Error(r.error.message); e.status = r.error.status; throw e; }
  return r.result;
}
async function rejects(promise, status) {
  try { await promise; } catch (e) { if (e.status !== status) throw new Error(`expected ${status}, got ${e.status}: ${e.message}`); return e; }
  throw new Error(`expected ${status}, call succeeded`);
}
function decode(v) {
  if (v == null) return v;
  if ('stringValue' in v) return v.stringValue;
  if ('booleanValue' in v) return v.booleanValue;
  if ('integerValue' in v) return Number(v.integerValue);
  if ('doubleValue' in v) return v.doubleValue;
  if ('nullValue' in v) return null;
  if ('timestampValue' in v) return v.timestampValue;
  if ('arrayValue' in v) return (v.arrayValue.values || []).map(decode);
  if ('mapValue' in v) return Object.fromEntries(Object.entries(v.mapValue.fields || {}).map(([k, x]) => [k, decode(x)]));
  return v;
}
async function read(path) {
  const r = await (await fetch(`${FS}/${path}`, { headers: { Authorization: 'Bearer owner' } })).json();
  if (r.error) return null;
  return Object.fromEntries(Object.entries(r.fields || {}).map(([k, v]) => [k, decode(v)]));
}
// fields: { 'a.b': value } — dotted paths update one nested field.
async function patch(path, fields) {
  const body = { fields: {} };
  for (const [key, v] of Object.entries(fields)) {
    const parts = key.split('.');
    let node = body.fields;
    for (const p of parts.slice(0, -1)) { node[p] ??= { mapValue: { fields: {} } }; node = node[p].mapValue.fields; }
    node[parts.at(-1)] = typeof v === 'object' ? v : typeof v === 'boolean' ? { booleanValue: v } : { stringValue: v };
  }
  const mask = Object.keys(fields).map((k) => `updateMask.fieldPaths=${encodeURIComponent(k)}`).join('&');
  await fetch(`${FS}/${path}?${mask}`, { method: 'PATCH', headers: { Authorization: 'Bearer owner', 'Content-Type': 'application/json' }, body: JSON.stringify(body) });
}

const HQ = { name: 'Head office', address: '12 MG Road', latitude: 12.9716, longitude: 77.5946, radius: 150 };
const company = (over = {}) => ({ companyName: 'Acme Logistics', adminName: 'Asha', location: HQ, shiftStart: '09:00', shiftEnd: '18:00', teamSize: '11–50', ...over });

console.log('registerCompany');
const boss = await emailUser('boss');
let co;
await t('requires sign-in', () => rejects(call('registerCompany', company()), 'UNAUTHENTICATED'));
await t('rejects a zone without coordinates', () => rejects(call('registerCompany', company({ location: { name: 'X', radius: 100 } }), boss), 'INVALID_ARGUMENT'));
await t('rejects a reversed shift', () => rejects(call('registerCompany', company({ shiftStart: '18:00', shiftEnd: '09:00' }), boss), 'INVALID_ARGUMENT'));
await t('creates company, main site, admin role, join code', async () => {
  co = await call('registerCompany', company(), boss);
  const c = await read(`companies/${co.companyId}`);
  eq(c.adminId, boss.uid, 'adminId'); eq(c.plan, 'trial', 'plan'); eq(c.employeeCode, co.employeeCode, 'code');
  eq(c.settings.approveJoiners, false, 'approveJoiners');
  eq(await read(`users/${boss.uid}`), { role: 'admin', companyId: co.companyId, viaCode: 'self-serve' }, 'role');
  eq((await read(`codes/${co.employeeCode}`)).companyId, co.companyId, 'code doc');
  if (Date.parse(c.trialEndsAt) - Date.now() < 13 * 86400000) throw new Error('trial too short');
});
await t('second company for the same account rejected', () => rejects(call('registerCompany', company(), boss), 'ALREADY_EXISTS'));

console.log('importEmployees');
const outsider = await emailUser('outsider');
const invitedPhone = freshPhone();
await t('non-admin cannot import', () => rejects(call('importEmployees', { companyId: co.companyId, rows: [{ name: 'X', phone: freshPhone() }] }, outsider), 'PERMISSION_DENIED'));
await t('empty list rejected', () => rejects(call('importEmployees', { companyId: co.companyId, rows: [] }, boss), 'INVALID_ARGUMENT'));
await t('valid rows invited, bad rows reported per row', async () => {
  const r = await call('importEmployees', { companyId: co.companyId, rows: [
    { name: 'Ravi', phone: invitedPhone.slice(3), department: 'Dispatch', location: 'head office', shiftStart: '08:00', shiftEnd: '17:00' },
    { name: 'Bad phone', phone: '12345' },
    { name: 'Dup', phone: invitedPhone },
    { name: 'Nowhere', phone: freshPhone(), location: 'Mars base' },
    { name: '', phone: freshPhone() },
  ] }, boss);
  eq(r.created, 1, 'created');
  eq(r.errors.map((e) => e.row), [1, 2, 3, 4], 'error rows');
  const inv = await read(`invites/${invitedPhone}`);
  eq(inv.companyId, co.companyId, 'invite company'); eq(inv.shift, { start: '08:00', end: '17:00' }, 'invite shift');
  eq(inv.locationIds.length, 1, 'invite site');
});
await t('re-importing the same phone updates the invite', async () => {
  const r = await call('importEmployees', { companyId: co.companyId, rows: [{ name: 'Ravi K', phone: invitedPhone }] }, boss);
  eq([r.created, r.updated], [0, 1], 'counts');
});
const boss2 = await emailUser('boss2');
const co2 = await call('registerCompany', company({ companyName: 'Other Co' }), boss2);
await t('another company cannot take over an invite', async () => {
  const r = await call('importEmployees', { companyId: co2.companyId, rows: [{ name: 'Poach', phone: invitedPhone }] }, boss2);
  eq(r.errors[0]?.message, 'Invited by another company', 'error');
});

console.log('claimJoin');
await t('requires sign-in', () => rejects(call('claimJoin', {}), 'UNAUTHENTICATED'));
const ravi = await phoneUser(invitedPhone);
await t('invited phone joins without a code, active, with invite details', async () => {
  const r = await call('claimJoin', {}, ravi);
  eq(r, { companyId: co.companyId, status: 'active' }, 'result');
  const e = await read(`companies/${co.companyId}/employees/${ravi.uid}`);
  eq([e.name, e.phone, e.department, e.status], ['Ravi K', invitedPhone, null, 'active'], 'employee');
  eq(e.locationIds.length, 1, 'sites'); eq(e.workLocation.radius, 150, 'legacy zone mirror');
  eq(await read(`invites/${invitedPhone}`), null, 'invite consumed');
  eq((await read(`users/${ravi.uid}`)).role, 'employee', 'role');
});
await t('joining twice rejected', () => rejects(call('claimJoin', {}, ravi), 'ALREADY_EXISTS'));
const stranger = await phoneUser(freshPhone());
await t('no invite and no code → not found', () => rejects(call('claimJoin', {}, stranger), 'NOT_FOUND'));
await t('wrong code → not found', () => rejects(call('claimJoin', { code: 'ZZZZZZ', name: 'S' }, stranger), 'NOT_FOUND'));
await t('code without a name rejected', () => rejects(call('claimJoin', { code: co.employeeCode }, stranger), 'INVALID_ARGUMENT'));
await t('code join puts them on the main site with default hours', async () => {
  eq(await call('claimJoin', { code: co.employeeCode.toLowerCase(), name: 'Sam' }, stranger), { companyId: co.companyId, status: 'active' }, 'result');
  const e = await read(`companies/${co.companyId}/employees/${stranger.uid}`);
  eq([e.name, e.shift.start, e.locationIds.length, e.primaryLocationId === e.locationIds[0]], ['Sam', '09:00', 1, true], 'employee');
  eq((await read(`companies/${co.companyId}`)).totalEmployees, 2, 'count');
});
await t('with approval on, code joiners are pending', async () => {
  await patch(`companies/${co.companyId}`, { 'settings.approveJoiners': true });
  const p = await phoneUser(freshPhone());
  eq((await call('claimJoin', { code: co.employeeCode, name: 'Pending Pat' }, p)).status, 'pending', 'status');
});
await t('suspended company refuses joiners', async () => {
  await patch(`companies/${co2.companyId}`, { status: 'suspended' });
  await rejects(call('claimJoin', { code: co2.employeeCode, name: 'X' }, await phoneUser(freshPhone())), 'FAILED_PRECONDITION');
});
await t('admin cannot join as an employee', () => rejects(call('claimJoin', { code: co.employeeCode, name: 'Boss' }, boss), 'ALREADY_EXISTS'));
await t('existing member cannot be re-invited', async () => {
  const r = await call('importEmployees', { companyId: co.companyId, rows: [{ name: 'Ravi', phone: invitedPhone }] }, boss);
  eq(r.errors[0]?.message, 'Already on your team', 'error');
});

console.log('resetJoinCode');
await t('non-admin cannot reset', () => rejects(call('resetJoinCode', { companyId: co.companyId }, ravi), 'PERMISSION_DENIED'));
await t('reset retires the old code', async () => {
  const { employeeCode } = await call('resetJoinCode', { companyId: co.companyId }, boss);
  if (employeeCode === co.employeeCode) throw new Error('code unchanged');
  eq(await read(`codes/${co.employeeCode}`), null, 'old code doc');
  eq((await read(`companies/${co.companyId}`)).employeeCode, employeeCode, 'company code');
  await rejects(call('claimJoin', { code: co.employeeCode, name: 'Late' }, await phoneUser(freshPhone())), 'NOT_FOUND');
});

console.log('billing');
const KEY_SECRET = 'fake_key_secret_for_emulator';
const WEBHOOK_SECRET = 'fake_webhook_secret_for_emulator';
const sign = (secret, payload) => createHmac('sha256', secret).update(payload).digest('hex');
async function webhook(event, entity, secret = WEBHOOK_SECRET) {
  const body = JSON.stringify({ event, payload: { subscription: { entity } } });
  const res = await fetch(`${FN}/razorpayWebhook`, { method: 'POST', headers: { 'Content-Type': 'application/json', 'X-Razorpay-Signature': sign(secret, body) }, body });
  return res.status;
}
let subId;
await t('non-admin cannot subscribe', () => rejects(call('createSubscription', { companyId: co.companyId, plan: 'pro', cycle: 'yearly', seats: 5 }, ravi), 'PERMISSION_DENIED'));
await t('unknown plan rejected', () => rejects(call('createSubscription', { companyId: co.companyId, plan: 'gold', cycle: 'yearly', seats: 5 }, boss), 'INVALID_ARGUMENT'));
await t('fewer seats than people rejected', () => rejects(call('createSubscription', { companyId: co.companyId, plan: 'pro', cycle: 'yearly', seats: 1 }, boss), 'INVALID_ARGUMENT'));
await t('trial company subscribes; first charge waits for trial end', async () => {
  const r = await call('createSubscription', { companyId: co.companyId, plan: 'pro', cycle: 'yearly', seats: 5 }, boss);
  subId = r.subscriptionId;
  eq([r.fake, r.subscriptionId.startsWith('sub_fake_')], [true, true], 'fake sub');
  const c = await read(`companies/${co.companyId}`);
  eq(c.pendingSubscription.id, subId, 'pending'); eq(c.plan, 'trial', 'still trial');
  if (Math.abs(r.startsAt - Date.parse(c.trialEndsAt)) > 1000) throw new Error('start not at trial end');
});
await t('forged checkout signature rejected', () => rejects(call('verifySubscription', { companyId: co.companyId, paymentId: 'pay_1', subscriptionId: subId, signature: 'deadbeef' }, boss), 'PERMISSION_DENIED'));
await t('verified checkout switches the company to Pro', async () => {
  await call('verifySubscription', { companyId: co.companyId, paymentId: 'pay_1', subscriptionId: subId, signature: sign(KEY_SECRET, `pay_1|${subId}`) }, boss);
  const c = await read(`companies/${co.companyId}`);
  eq([c.plan, c.cycle, c.seats, c.billingStatus, c.subscriptionId, c.pendingSubscription], ['pro', 'yearly', 5, 'authenticated', subId, undefined], 'company');
});
await t('webhook with a bad signature is refused', async () => eq(await webhook('subscription.activated', { id: subId, status: 'active', notes: { companyId: co.companyId, plan: 'business', cycle: 'yearly' } }, 'wrong'), 400, 'status'));
await t('webhook activates and records the period end', async () => {
  eq(await webhook('subscription.activated', { id: subId, status: 'active', quantity: 6, current_end: 1893456000, notes: { companyId: co.companyId, plan: 'pro', cycle: 'yearly' } }), 200, 'status');
  const c = await read(`companies/${co.companyId}`);
  eq([c.billingStatus, c.seats, c.currentPeriodEnd.slice(0, 10)], ['active', 6, '2030-01-01'], 'company');
});
await t('webhook for someone else’s subscription changes nothing', async () => {
  await webhook('subscription.cancelled', { id: 'sub_other', status: 'cancelled', notes: { companyId: co.companyId, plan: 'pro', cycle: 'yearly' } });
  eq((await read(`companies/${co.companyId}`)).billingStatus, 'active', 'status');
});
await t('halted subscription drops the company to Free', async () => {
  await webhook('subscription.halted', { id: subId, status: 'halted', notes: { companyId: co.companyId, plan: 'pro', cycle: 'yearly' } });
  const c = await read(`companies/${co.companyId}`);
  eq([c.plan, c.billingStatus], ['free', 'halted'], 'company');
});
await t('cancel needs a live subscription', () => rejects(call('cancelSubscription', { companyId: co.companyId }, boss), 'FAILED_PRECONDITION'));

console.log('free plan limits');
const heads = async () => (await (await fetch(`${FS}:runAggregationQuery`.replace('/documents:', `/documents/companies/${co.companyId}:`), { method: 'POST', headers: { Authorization: 'Bearer owner', 'Content-Type': 'application/json' }, body: JSON.stringify({ structuredAggregationQuery: { structuredQuery: { from: [{ collectionId: 'employees' }], where: { fieldFilter: { field: { fieldPath: 'status' }, op: 'IN', value: { arrayValue: { values: [{ stringValue: 'active' }, { stringValue: 'pending' }] } } } } }, aggregations: [{ alias: 'n', count: {} }] } }) })).json())[0].result.aggregateFields.n.integerValue;
const before = Number(await heads());
const p1 = freshPhone(), p2 = freshPhone(), p3 = freshPhone();
await t('Free company can only invite up to 5 people', async () => {
  const r = await call('importEmployees', { companyId: co.companyId, rows: [p1, p2, p3].map((phone, i) => ({ name: `Free ${i}`, phone })) }, boss);
  eq(r.created, 5 - before, 'created'); eq(r.errors.length, 3 - (5 - before), 'refused');
});
await t('joining past 5 on Free is refused', async () => {
  for (const p of [p1, p2].slice(0, 5 - before)) await call('claimJoin', {}, await phoneUser(p));
  const code = (await read(`companies/${co.companyId}`)).employeeCode;
  await rejects(call('claimJoin', { code, name: 'Sixth' }, await phoneUser(freshPhone())), 'RESOURCE_EXHAUSTED');
});
await t('trigger keeps activeEmployees in step', async () => {
  for (let i = 0; i < 20 && (await read(`companies/${co.companyId}`)).activeEmployees !== 5; i++) await new Promise((r) => setTimeout(r, 500));
  eq((await read(`companies/${co.companyId}`)).activeEmployees, 5, 'activeEmployees');
});

console.log('deleteMyAccount');
await t('requires sign-in', () => rejects(call('deleteMyAccount', {}), 'UNAUTHENTICATED'));
await t('company owner is pointed to support', () => rejects(call('deleteMyAccount', {}, boss), 'FAILED_PRECONDITION'));
await t('employee removes their profile, records, membership and login', async () => {
  // The Free company may be full from the limit tests; a live trial lifts the cap.
  await patch(`companies/${co.companyId}`, { plan: 'trial', trialEndsAt: { timestampValue: new Date(Date.now() + 864e5).toISOString() } });
  const code = (await read(`companies/${co.companyId}`)).employeeCode;
  const leaver = await phoneUser(freshPhone());
  await call('claimJoin', { code, name: 'Leaver' }, leaver);
  await fetch(`${FS}/companies/${co.companyId}/attendance?documentId=${leaver.uid}_2026-01-05`, { method: 'POST', headers: { Authorization: 'Bearer owner', 'Content-Type': 'application/json' }, body: JSON.stringify({ fields: { employeeId: { stringValue: leaver.uid }, date: { stringValue: '2026-01-05' } } }) });
  eq((await read(`companies/${co.companyId}/attendance/${leaver.uid}_2026-01-05`)).date, '2026-01-05', 'attendance before');
  eq((await read(`users/${leaver.uid}`)).role, 'employee', 'role before');
  eq(await call('deleteMyAccount', {}, leaver), { deleted: true }, 'result');
  eq(await read(`users/${leaver.uid}`), null, 'role doc');
  eq(await read(`companies/${co.companyId}/employees/${leaver.uid}`), null, 'employee doc');
  eq(await read(`companies/${co.companyId}/attendance/${leaver.uid}_2026-01-05`), null, 'attendance record');
  const lookup = await post(`${AUTH}/identitytoolkit.googleapis.com/v1/accounts:lookup?key=fake`, { idToken: leaver.token });
  eq(Boolean(lookup.users?.length), false, 'auth user still there');
});

console.log(`\n${pass} passed, ${failN} failed`);
process.exit(failN ? 1 : 0);
