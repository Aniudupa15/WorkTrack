const { test } = require("node:test");
const assert = require("node:assert/strict");
const { reminderFor, inReminderWindow, format12, leaveCovers } = require("../reminders");

const shift = { start: "09:00", end: "18:00" };
const at = (hhmm) => { const [h, m] = hhmm.split(":").map(Number); return h * 60 + m; };

test("12-hour times", () => {
  assert.equal(format12("09:00"), "9:00 AM");
  assert.equal(format12("12:30"), "12:30 PM");
  assert.equal(format12("00:05"), "12:05 AM");
  assert.equal(format12("18:00"), "6:00 PM");
});

test("check-in nudge only in the 5 minutes before the shift, if not in yet", () => {
  assert.deepEqual(reminderFor({ shift, nowMinutes: at("08:55"), attendance: null, onLeave: false, siteName: "Head office" }), {
    title: "Your shift starts at 9:00 AM",
    body: "Punch in when you reach Head office.",
  });
  assert.equal(reminderFor({ shift, nowMinutes: at("08:50"), attendance: null, onLeave: false }), null);
  assert.equal(reminderFor({ shift, nowMinutes: at("09:00"), attendance: null, onLeave: false }), null);
  assert.equal(reminderFor({ shift, nowMinutes: at("08:57"), attendance: { checkIn: 1 }, onLeave: false }), null);
});

test("check-out nudge 30–35 minutes after the shift, if still in", () => {
  const r = reminderFor({ shift, nowMinutes: at("18:32"), attendance: { checkIn: 1 }, onLeave: false });
  assert.equal(r.title, "You’re still punched in");
  assert.match(r.body, /6:00 PM/);
  assert.equal(reminderFor({ shift, nowMinutes: at("18:32"), attendance: { checkIn: 1, checkOut: 2 }, onLeave: false }), null);
  assert.equal(reminderFor({ shift, nowMinutes: at("18:32"), attendance: null, onLeave: false }), null);
  assert.equal(reminderFor({ shift, nowMinutes: at("18:36"), attendance: { checkIn: 1 }, onLeave: false }), null);
});

test("nobody on leave is nudged", () => {
  assert.equal(reminderFor({ shift, nowMinutes: at("08:55"), attendance: null, onLeave: true }), null);
});

test("leave covers whole days inclusively", () => {
  // Picked as 12–13 Nov on a phone in India: midnights IST = 18:30 UTC the day before.
  const leave = { startDate: new Date("2026-11-11T18:30:00Z"), endDate: new Date("2026-11-12T18:30:00Z") };
  assert.equal(leaveCovers(leave, "2026-11-11"), false);
  assert.equal(leaveCovers(leave, "2026-11-12"), true);
  assert.equal(leaveCovers(leave, "2026-11-13"), true);
  assert.equal(leaveCovers(leave, "2026-11-14"), false);
});

test("window pre-check matches the reminder windows", () => {
  for (const [t, expected] of [["08:54", false], ["08:55", true], ["08:59", true], ["09:00", false], ["18:29", false], ["18:30", true], ["18:34", true], ["18:35", false]]) {
    assert.equal(inReminderWindow(shift, at(t)), expected, t);
  }
});
