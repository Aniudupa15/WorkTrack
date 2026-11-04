import { initializeTestEnvironment, assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { doc, getDoc, setDoc, updateDoc, deleteDoc, writeBatch, serverTimestamp, Timestamp, collection, query, where, getDocs } from 'firebase/firestore';

const env = await initializeTestEnvironment({ projectId: 'demo-punchin', firestore: { rules: readFileSync(fileURLToPath(new URL('../../firestore.rules', import.meta.url)), 'utf8'), host: '127.0.0.1', port: 8085 } });
const C = 'co1', E = 'emp1', ZONE = { latitude: 12.9716, longitude: 77.5946, radius: 100, address: 'HQ' };
const ist = () => new Date(Date.now() + 330 * 60000);
const today = () => ist().toISOString().slice(0, 10);
const hhmm = (mins) => { mins = Math.max(0, Math.min(1439, mins)); return `${String(Math.floor(mins / 60)).padStart(2, '0')}:${String(mins % 60).padStart(2, '0')}`; };
const nowMin = () => ist().getUTCHours() * 60 + ist().getUTCMinutes();
const fix = (dLatM = 0, acc = 15) => ({ latitude: ZONE.latitude + dLatM / 111320, longitude: ZONE.longitude, accuracy: acc });
let pass = 0, failN = 0;
async function t(name, fn) { try { await fn(); pass++; console.log('  ok   ', name); } catch (e) { failN++; console.log('  FAIL ', name, '-', e.message); } }

async function seed({ shiftStart, shiftEnd, status = 'active', zone = ZONE, companyStatus = 'active' }) {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'companies', C), { companyId: C, companyName: 'Acme', adminId: '', adminName: 'A', adminEmail: 'boss@acme.com', status: companyStatus, employeeCode: 'EMPCODE', settings: {}, totalEmployees: 0 });
    await setDoc(doc(db, 'users', E), { role: 'employee', companyId: C, viaCode: 'EMPCODE' });
    await setDoc(doc(db, 'companies', C, 'employees', E), { uid: E, name: 'Emp', email: 'e@acme.com', status, workLocation: zone, shift: { start: shiftStart, end: shiftEnd } });
    await setDoc(doc(db, 'codes', 'EMPCODE'), { companyId: C, type: 'employee' });
    await setDoc(doc(db, 'codes', 'ADMCODE'), { companyId: C, type: 'admin', used: false, claimedBy: null, intendedEmail: 'boss@acme.com' });
  });
}
const empDb = () => env.authenticatedContext(E, { email: 'e@acme.com' }).firestore();
const rec = (over = {}) => ({ employeeId: E, companyId: C, employeeName: 'Emp', date: today(), checkIn: serverTimestamp(), checkOut: null, status: 'present', isLate: false, checkInLocation: fix(), checkOutLocation: null, selfieStoragePath: null, isSynced: true, notes: null, ...over });
const attRef = (db, id = `${E}_${today()}`) => doc(db, 'companies', C, 'attendance', id);
const onTime = { shiftStart: hhmm(nowMin() + 30), shiftEnd: hhmm(nowMin() + 120) };
const lateShift = { shiftStart: hhmm(nowMin() - 60), shiftEnd: hhmm(nowMin() + 120) };
console.log('IST now', ist().toISOString(), 'shifts', onTime, lateShift);

console.log('Check-in');
await seed(onTime);
await t('on-time check-in inside zone succeeds', () => assertSucceeds(setDoc(attRef(empDb()), rec())));
await seed(onTime);
await t('device-clock checkIn timestamp rejected', () => assertFails(setDoc(attRef(empDb()), rec({ checkIn: Timestamp.fromDate(new Date(Date.now() - 3600e3)) }))));
await t('check-in 500 m outside zone rejected', () => assertFails(setDoc(attRef(empDb()), rec({ checkInLocation: fix(500) }))));
await t('check-in 80 m away (inside 100 m) succeeds', async () => { await assertSucceeds(setDoc(attRef(empDb()), rec({ checkInLocation: fix(80) }))); await seed(onTime); });
await t('check-in 120 m away (outside 100 m) rejected', () => assertFails(setDoc(attRef(empDb()), rec({ checkInLocation: fix(120) }))));
await t('accuracy > 100 m rejected', () => assertFails(setDoc(attRef(empDb()), rec({ checkInLocation: fix(0, 250) }))));
await t('missing accuracy rejected', () => assertFails(setDoc(attRef(empDb()), rec({ checkInLocation: { latitude: ZONE.latitude, longitude: ZONE.longitude } }))));
await t('backdated day rejected', () => assertFails(setDoc(attRef(empDb(), `${E}_2020-01-01`), rec({ date: '2020-01-01' }))));
await t('other employee id rejected', () => assertFails(setDoc(attRef(empDb(), `emp2_${today()}`), rec({ employeeId: 'emp2' }))));
await t('extra fields rejected', () => assertFails(setDoc(attRef(empDb()), rec({ approvedBy: 'me' }))));
await t('foreign selfie path rejected', () => assertFails(setDoc(attRef(empDb()), rec({ selfieStoragePath: 'selfies/co1/emp2/x.jpg' }))));
await t('own selfie path succeeds', async () => { await assertSucceeds(setDoc(attRef(empDb()), rec({ selfieStoragePath: `selfies/${C}/${E}/1.jpg` }))); });
await seed(lateShift);
await t('late employee claiming "present" rejected', () => assertFails(setDoc(attRef(empDb()), rec())));
await t('late employee flagged late succeeds', () => assertSucceeds(setDoc(attRef(empDb()), rec({ isLate: true, status: 'late' }))));
await t('second check-in same day rejected', () => assertFails(setDoc(attRef(empDb()), rec({ isLate: true, status: 'late' }))));
await seed({ shiftStart: hhmm(nowMin() - 300), shiftEnd: hhmm(nowMin() - 60) });
await t('check-in after shift end rejected', () => assertFails(setDoc(attRef(empDb()), rec({ isLate: true, status: 'late' }))));
await seed({ ...onTime, status: 'inactive' });
await t('deactivated employee rejected', () => assertFails(setDoc(attRef(empDb()), rec())));
await seed({ ...onTime, companyStatus: 'suspended' });
await t('suspended company rejected', () => assertFails(setDoc(attRef(empDb()), rec())));
await seed({ ...onTime, zone: null });
await t('no work location assigned rejected', () => assertFails(setDoc(attRef(empDb()), rec())));

console.log('Check-out / tampering');
await seed(onTime);
await setDoc(attRef(empDb()), rec());
await t('tamper status/checkIn after punch rejected', () => assertFails(updateDoc(attRef(empDb()), { status: 'present', checkIn: Timestamp.fromDate(new Date(Date.now() - 7200e3)) })));
await t('check-out with device timestamp rejected', () => assertFails(updateDoc(attRef(empDb()), { checkOut: Timestamp.now(), checkOutLocation: fix() })));
await t('check-out outside zone rejected', () => assertFails(updateDoc(attRef(empDb()), { checkOut: serverTimestamp(), checkOutLocation: fix(900) })));
await t('valid check-out succeeds', () => assertSucceeds(updateDoc(attRef(empDb()), { checkOut: serverTimestamp(), checkOutLocation: fix() })));
await t('second check-out rejected', () => assertFails(updateDoc(attRef(empDb()), { checkOut: serverTimestamp(), checkOutLocation: fix() })));
await t('employee cannot delete record', () => assertFails(deleteDoc(attRef(empDb()))));
await t('employee reads today attendance query', () => assertSucceeds(getDocs(query(collection(empDb(), 'companies', C, 'attendance'), where('employeeId', '==', E), where('date', '==', today())))));

console.log('Registration / company');
await seed(onTime);
const newEmp = (zone) => { const db = env.authenticatedContext('new1', { email: 'new@acme.com' }).firestore(); const b = writeBatch(db);
  b.set(doc(db, 'companies', C, 'employees', 'new1'), { uid: 'new1', name: 'New', email: 'New@acme.com', phone: null, department: null, position: null, status: 'active', avatarUrl: null, workLocation: zone, shift: { start: '09:00', end: '18:00' }, fcmToken: null, joinedAt: serverTimestamp() });
  b.set(doc(db, 'users', 'new1'), { role: 'employee', companyId: C, viaCode: 'EMPCODE' }); return b.commit(); };
await t('self-join setting own geofence rejected', () => assertFails(newEmp({ ...ZONE, latitude: 0, longitude: 0 })));
await t('bare self-join with employee code succeeds', () => assertSucceeds(newEmp(null)));
await t('stranger cannot create employee profile', () => assertFails(setDoc(doc(env.authenticatedContext('x9', { email: 'x@x.com' }).firestore(), 'companies', C, 'employees', 'x9'), { uid: 'x9', name: 'X', email: 'x@x.com', phone: null, department: null, position: null, status: 'active', avatarUrl: null, workLocation: null, shift: { start: '09:00', end: '18:00' }, fcmToken: null, joinedAt: serverTimestamp() })));
const claim = (uid, email) => { const db = env.authenticatedContext(uid, { email }).firestore(); const b = writeBatch(db);
  b.update(doc(db, 'codes', 'ADMCODE'), { used: true, claimedBy: uid });
  b.set(doc(db, 'users', uid), { role: 'admin', companyId: C, viaCode: 'ADMCODE' });
  b.update(doc(db, 'companies', C), { adminId: uid, adminName: 'Boss', adminEmail: email }); return b.commit(); };
await t('admin code claimed by wrong email rejected', () => assertFails(claim('evil', 'evil@x.com')));
await t('atomic admin claim by intended email succeeds', () => assertSucceeds(claim('boss', 'boss@acme.com')));
await t('admin code cannot be claimed twice', () => assertFails(claim('boss2', 'boss@acme.com')));
const admDb = env.authenticatedContext('boss', { email: 'boss@acme.com' }).firestore();
await env.withSecurityRulesDisabled((ctx) => updateDoc(doc(ctx.firestore(), 'companies', C), { status: 'suspended' }));
await t('admin cannot un-suspend company', () => assertFails(updateDoc(doc(admDb, 'companies', C), { status: 'active' })));
await env.withSecurityRulesDisabled((ctx) => updateDoc(doc(ctx.firestore(), 'companies', C), { status: 'active' }));
await t('admin cannot change employee code', () => assertFails(updateDoc(doc(admDb, 'companies', C), { employeeCode: 'NEW' })));
await t('admin cannot re-point adminId', () => assertFails(updateDoc(doc(admDb, 'companies', C), { adminId: 'someoneelse' })));
await t('admin can update settings', () => assertSucceeds(updateDoc(doc(admDb, 'companies', C), { settings: { defaultRadius: 150, defaultShiftStart: '09:00', defaultShiftEnd: '18:00' } })));
await t('admin sets valid work location', () => assertSucceeds(updateDoc(doc(admDb, 'companies', C, 'employees', E), { name: 'Emp', phone: null, department: null, position: null, workLocation: ZONE, shift: { start: '09:00', end: '18:00' }, updatedAt: serverTimestamp() })));
await t('admin deactivates employee', () => assertSucceeds(updateDoc(doc(admDb, 'companies', C, 'employees', E), { status: 'inactive' })));
await t('admin invalid radius rejected', () => assertFails(updateDoc(doc(admDb, 'companies', C, 'employees', E), { workLocation: { ...ZONE, radius: 99999 } })));
await t('admin reversed shift rejected', () => assertFails(updateDoc(doc(admDb, 'companies', C, 'employees', E), { shift: { start: '18:00', end: '09:00' } })));
await t('employee can update own fcmToken', () => assertSucceeds(updateDoc(doc(empDb(), 'companies', C, 'employees', E), { fcmToken: 'tok' })));
await t('employee cannot move own geofence', () => assertFails(updateDoc(doc(empDb(), 'companies', C, 'employees', E), { workLocation: { ...ZONE, latitude: 1 } })));

console.log('Leaves');
await seed(onTime);
const leave = (over = {}) => ({ id: 'l1', employeeId: E, companyId: C, employeeName: 'Emp', type: 'sick', startDate: Timestamp.fromDate(new Date('2026-11-02')), endDate: Timestamp.fromDate(new Date('2026-11-03')), reason: 'flu', status: 'pending', createdAt: serverTimestamp(), updatedAt: null, adminNote: null, ...over });
await t('valid leave request succeeds', () => assertSucceeds(setDoc(doc(empDb(), 'companies', C, 'leaves', 'l1'), leave())));
await t('self-approved leave rejected', () => assertFails(setDoc(doc(empDb(), 'companies', C, 'leaves', 'l2'), leave({ status: 'approved' }))));
await t('end before start rejected', () => assertFails(setDoc(doc(empDb(), 'companies', C, 'leaves', 'l3'), leave({ endDate: Timestamp.fromDate(new Date('2026-11-01')) }))));
await env.withSecurityRulesDisabled((ctx) => setDoc(doc(ctx.firestore(), 'users', 'adm1'), { role: 'admin', companyId: C, viaCode: 'X' }));
const adm1 = env.authenticatedContext('adm1', { email: 'boss@acme.com' }).firestore();
await t('admin approves leave', () => assertSucceeds(updateDoc(doc(adm1, 'companies', C, 'leaves', 'l1'), { status: 'approved', adminNote: 'ok', updatedAt: serverTimestamp() })));
await t('employee cannot approve own leave', () => assertFails(updateDoc(doc(empDb(), 'companies', C, 'leaves', 'l1'), { status: 'approved' })));

console.log('Multi-site');
const north = (m) => ({ latitude: ZONE.latitude + m / 111320, longitude: ZONE.longitude, radius: 150 });
const SITE = {
  s1: { name: 'Head office', address: 'HQ', ...ZONE, isMain: true },
  s2: { name: 'Warehouse', address: 'WH', ...north(2000), isMain: false },
  s3: { name: 'Other', address: null, ...north(5000), isMain: false },
};
const atSite = (id, dM = 0, acc = 12) => ({ latitude: SITE[id].latitude + dM / 111320, longitude: SITE[id].longitude, accuracy: acc });
async function seedSites(extra = {}) {
  await seed(onTime);
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    for (const [id, s] of Object.entries(SITE)) await setDoc(doc(db, 'companies', C, 'locations', id), { ...s, createdAt: Timestamp.now() });
    await updateDoc(doc(db, 'companies', C, 'employees', E), { locationIds: ['s1', 's2'], primaryLocationId: 's1', ...extra });
    await setDoc(doc(db, 'users', 'adm1'), { role: 'admin', companyId: C, viaCode: 'X' });
  });
}
const adm = () => env.authenticatedContext('adm1', { email: 'boss@acme.com' }).firestore();
await seedSites();
await t('check-in at second assigned site succeeds', () => assertSucceeds(setDoc(attRef(empDb()), rec({ checkInLocation: atSite('s2'), locationId: 's2', locationName: 'Warehouse' }))));
await seedSites();
await t('check-in at site B naming site A rejected', () => assertFails(setDoc(attRef(empDb()), rec({ checkInLocation: atSite('s2'), locationId: 's1' }))));
await t('check-in at unassigned company site rejected', () => assertFails(setDoc(attRef(empDb()), rec({ checkInLocation: atSite('s3'), locationId: 's3' }))));
await t('check-in naming a missing site rejected', () => assertFails(setDoc(attRef(empDb()), rec({ locationId: 'nope' }))));
await t('check-in 200 m outside site B (150 m) rejected', () => assertFails(setDoc(attRef(empDb()), rec({ checkInLocation: atSite('s2', 200), locationId: 's2' }))));
await t('legacy client at site B (no locationId) rejected', () => assertFails(setDoc(attRef(empDb()), rec({ checkInLocation: atSite('s2') }))));
await t('legacy client at legacy zone succeeds', () => assertSucceeds(setDoc(attRef(empDb()), rec())));
await t('check-out at other assigned site succeeds', () => assertSucceeds(updateDoc(attRef(empDb()), { checkOut: serverTimestamp(), checkOutLocation: atSite('s2'), checkOutLocationId: 's2' })));
await seedSites();
await setDoc(attRef(empDb()), rec({ locationId: 's1' }));
await t('check-out at unassigned site rejected', () => assertFails(updateDoc(attRef(empDb()), { checkOut: serverTimestamp(), checkOutLocation: atSite('s3'), checkOutLocationId: 's3' })));
await t('check-out may not rewrite the check-in site', () => assertFails(updateDoc(attRef(empDb()), { checkOut: serverTimestamp(), checkOutLocation: atSite('s1'), locationId: 's2' })));
await seedSites();
await env.withSecurityRulesDisabled((ctx) => deleteDoc(doc(ctx.firestore(), 'companies', C, 'locations', 's2')));
await t('punch at a deleted site rejected', () => assertFails(setDoc(attRef(empDb()), rec({ checkInLocation: atSite('s2'), locationId: 's2' }))));

console.log('Locations / assignment');
await seedSites();
const newSite = (over = {}) => ({ name: 'Depot', address: 'Ring Rd', latitude: 12.9, longitude: 77.6, radius: 120, isMain: false, createdAt: serverTimestamp(), updatedAt: serverTimestamp(), ...over });
await t('admin adds a location', () => assertSucceeds(setDoc(doc(adm(), 'companies', C, 'locations', 'n1'), newSite())));
await t('location radius 9999 m rejected', () => assertFails(setDoc(doc(adm(), 'companies', C, 'locations', 'n2'), newSite({ radius: 9999 }))));
await t('location without name rejected', () => assertFails(setDoc(doc(adm(), 'companies', C, 'locations', 'n3'), newSite({ name: '' }))));
await t('location extra field rejected', () => assertFails(setDoc(doc(adm(), 'companies', C, 'locations', 'n4'), newSite({ owner: 'x' }))));
await t('admin moves a location', () => assertSucceeds(updateDoc(doc(adm(), 'companies', C, 'locations', 'n1'), { latitude: 12.91, updatedAt: serverTimestamp() })));
await t('admin cannot rewrite createdAt', () => assertFails(updateDoc(doc(adm(), 'companies', C, 'locations', 'n1'), { createdAt: Timestamp.fromDate(new Date('2020-01-01')) })));
await t('employee cannot add a location', () => assertFails(setDoc(doc(empDb(), 'companies', C, 'locations', 'n5'), newSite())));
await t('employee cannot move a location', () => assertFails(updateDoc(doc(empDb(), 'companies', C, 'locations', 's1'), { latitude: 1 })));
await t('employee reads company locations', () => assertSucceeds(getDocs(collection(empDb(), 'companies', C, 'locations'))));
await t('outsider cannot read locations', () => assertFails(getDocs(collection(env.authenticatedContext('x9', { email: 'x@x.com' }).firestore(), 'companies', C, 'locations'))));
const assign = (ids, primary) => updateDoc(doc(adm(), 'companies', C, 'employees', E), { locationIds: ids, primaryLocationId: primary, workLocation: ZONE, updatedAt: serverTimestamp() });
await t('admin assigns three sites', () => assertSucceeds(assign(['s1', 's2', 's3'], 's2')));
await t('primary outside the assigned list rejected', () => assertFails(assign(['s1'], 's2')));
await t('more than 10 sites rejected', () => assertFails(assign(Array.from({ length: 11 }, (_, i) => `x${i}`), 'x0')));
await t('admin clears all sites', () => assertSucceeds(assign([], null)));
await t('employee cannot assign themselves a site', () => assertFails(updateDoc(doc(empDb(), 'companies', C, 'employees', E), { locationIds: ['s3'], primaryLocationId: 's3' })));
const joinWith = (ids, primary) => { const db = env.authenticatedContext('new2', { email: 'new2@acme.com' }).firestore(); const b = writeBatch(db);
  b.set(doc(db, 'companies', C, 'employees', 'new2'), { uid: 'new2', name: 'New', email: 'new2@acme.com', phone: null, department: null, position: null, status: 'active', avatarUrl: null, workLocation: null, locationIds: ids, primaryLocationId: primary, shift: { start: '09:00', end: '18:00' }, fcmToken: null, joinedAt: serverTimestamp() });
  b.set(doc(db, 'users', 'new2'), { role: 'employee', companyId: C, viaCode: 'EMPCODE' }); return b.commit(); };
await t('self-join onto a non-main site rejected', () => assertFails(joinWith(['s2'], 's2')));
await t('self-join onto two sites rejected', () => assertFails(joinWith(['s1', 's2'], 's1')));
await t('self-join onto the main site succeeds', () => assertSucceeds(joinWith(['s1'], 's1')));

console.log('Invites / pending joiners');
await seedSites();
await env.withSecurityRulesDisabled(async (ctx) => {
  const db = ctx.firestore();
  await setDoc(doc(db, 'invites', '+919800000001'), { companyId: C, name: 'Inv', phone: '+919800000001' });
  await setDoc(doc(db, 'invites', '+919800000002'), { companyId: 'other', name: 'Else', phone: '+919800000002' });
});
await t('admin lists own company invites', () => assertSucceeds(getDocs(query(collection(adm(), 'invites'), where('companyId', '==', C)))));
await t('admin cannot read another company invite', () => assertFails(getDocs(query(collection(adm(), 'invites'), where('companyId', '==', 'other')))));
await t('admin withdraws own invite', () => assertSucceeds(deleteDoc(doc(adm(), 'invites', '+919800000001'))));
await t('admin cannot write invites directly', () => assertFails(setDoc(doc(adm(), 'invites', '+919800000003'), { companyId: C, name: 'X' })));
await t('employee cannot read invites', () => assertFails(getDocs(query(collection(empDb(), 'invites'), where('companyId', '==', C)))));
await env.withSecurityRulesDisabled((ctx) => updateDoc(doc(ctx.firestore(), 'companies', C, 'employees', E), { status: 'pending' }));
await t('pending joiner cannot punch', () => assertFails(setDoc(attRef(empDb()), rec({ locationId: 's1' }))));
await t('pending joiner cannot approve themselves', () => assertFails(updateDoc(doc(empDb(), 'companies', C, 'employees', E), { status: 'active' })));
await t('admin approves a pending joiner', () => assertSucceeds(updateDoc(doc(adm(), 'companies', C, 'employees', E), { status: 'active', updatedAt: serverTimestamp() })));
await t('client cannot create a company', () => assertFails(setDoc(doc(adm(), 'companies', 'mine'), { companyName: 'X', adminId: 'adm1' })));
await t('admin cannot grant itself a paid plan', () => assertFails(updateDoc(doc(adm(), 'companies', C), { plan: 'business' })));

console.log('Plans / billing');
const istDay = (daysAgo) => new Date(Date.now() + 330 * 60000 - daysAgo * 86400000).toISOString().slice(0, 10);
async function seedPlan(fields) {
  await seedSites();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await updateDoc(doc(db, 'companies', C), fields);
    for (const d of [0, 10, 45]) await setDoc(doc(db, 'companies', C, 'attendance', `${E}_${istDay(d)}`), { employeeId: E, companyId: C, date: istDay(d), status: 'present' });
    await setDoc(doc(db, 'companies', C, 'employees', 'gone'), { uid: 'gone', name: 'Gone', status: 'inactive', shift: { start: '09:00', end: '18:00' } });
  });
}
const att = (db) => collection(db, 'companies', C, 'attendance');
const reactivate = () => updateDoc(doc(adm(), 'companies', C, 'employees', 'gone'), { status: 'active', updatedAt: serverTimestamp() });
await seedPlan({ plan: 'free', activeEmployees: 5 });
await t('Free admin: last 30 days readable', () => assertSucceeds(getDocs(query(att(adm()), where('date', '>=', istDay(29))))));
await t('Free admin: today’s logs readable', () => assertSucceeds(getDocs(query(att(adm()), where('date', '==', istDay(0))))));
await t('Free admin: 45-day-old record refused', () => assertFails(getDoc(doc(att(adm()), `${E}_${istDay(45)}`))));
await t('Free admin: unbounded history query refused', () => assertFails(getDocs(att(adm()))));
await t('Free employee still reads own old record', () => assertSucceeds(getDoc(doc(att(empDb()), `${E}_${istDay(45)}`))));
await t('Free company at 5 cannot reactivate a sixth', () => assertFails(reactivate()));
await seedPlan({ plan: 'free', activeEmployees: 4 });
await t('Free company at 4 can reactivate one', () => assertSucceeds(reactivate()));
await seedPlan({ plan: 'trial', trialEndsAt: Timestamp.fromDate(new Date(Date.now() + 5 * 86400000)), activeEmployees: 9 });
await t('trial: full history and no headcount cap', async () => { await assertSucceeds(getDocs(att(adm()))); await assertSucceeds(reactivate()); });
await seedPlan({ plan: 'trial', trialEndsAt: Timestamp.fromDate(new Date(Date.now() - 86400000)), activeEmployees: 9 });
await t('expired trial behaves as Free', () => assertFails(getDocs(att(adm()))));
await seedPlan({ plan: 'pro', billingStatus: 'active', activeEmployees: 40 });
await t('active Pro: full history', () => assertSucceeds(getDocs(att(adm()))));
await seedPlan({ plan: 'pro', billingStatus: 'halted', activeEmployees: 40 });
await t('halted Pro behaves as Free', () => assertFails(getDocs(att(adm()))));
await seedPlan({ activeEmployees: 40 });
await t('pre-billing company is unrestricted', async () => { await assertSucceeds(getDocs(att(adm()))); await assertSucceeds(reactivate()); });
for (const [field, value] of [['seats', 999], ['billingStatus', 'active'], ['trialEndsAt', Timestamp.fromDate(new Date('2030-01-01'))], ['activeEmployees', 0], ['subscriptionId', 'sub_x']]) {
  await t(`admin cannot write ${field}`, () => assertFails(updateDoc(doc(adm(), 'companies', C), { [field]: value })));
}

console.log(`\n${pass} passed, ${failN} failed`);
await env.cleanup();
process.exit(failN ? 1 : 0);
