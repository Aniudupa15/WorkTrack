// What shift reminder (if any) an employee should get right now. Pure, so it
// can be unit-tested without Firebase: `node --test` in cloud_functions/.

// Check-in nudge in the 5 minutes before the shift starts; check-out nudge
// 30–35 minutes after it ends. The scheduler runs every 5 minutes, so each
// window fires about once a day.
const CHECK_IN_LEAD = 5;
const CHECK_OUT_AFTER = 30;
const WINDOW = 5;

function toMinutes(hhmm) {
  if (typeof hhmm !== "string" || !/^([01]\d|2[0-3]):[0-5]\d$/.test(hhmm)) return null;
  const [h, m] = hhmm.split(":").map(Number);
  return h * 60 + m;
}

// "18:00" → "6:00 PM"
function format12(hhmm) {
  const minutes = toMinutes(hhmm);
  if (minutes == null) return hhmm;
  const h = Math.floor(minutes / 60), m = minutes % 60;
  return `${h % 12 === 0 ? 12 : h % 12}:${String(m).padStart(2, "0")} ${h < 12 ? "AM" : "PM"}`;
}

const UTC_OFFSET_MINUTES = 330; // company time (IST); matches the app and Rules

// date: the company's "YYYY-MM-DD"; leave dates are midnights in company time.
function leaveCovers(leave, date) {
  const day = (d) => new Date(d.getTime() + UTC_OFFSET_MINUTES * 60000).toISOString().slice(0, 10);
  return day(leave.startDate) <= date && date <= day(leave.endDate);
}

/**
 * @param {{ start: string, end: string }} shift
 * @param {number} nowMinutes  minutes past midnight, company time
 * @param {{ checkIn?: any, checkOut?: any } | null} attendance  today's record
 * @param {boolean} onLeave
 * @param {string | null} siteName  the employee's primary site
 * @returns {{ title: string, body: string } | null}
 */
function reminderFor({ shift, nowMinutes, attendance, onLeave, siteName }) {
  if (onLeave) return null;
  const start = toMinutes(shift?.start), end = toMinutes(shift?.end);
  if (start != null && nowMinutes >= start - CHECK_IN_LEAD && nowMinutes < start - CHECK_IN_LEAD + WINDOW && !attendance?.checkIn) {
    return {
      title: `Your shift starts at ${format12(shift.start)}`,
      body: siteName ? `Punch in when you reach ${siteName}.` : "Punch in when you arrive.",
    };
  }
  const after = end == null ? null : end + CHECK_OUT_AFTER;
  if (after != null && nowMinutes >= after && nowMinutes < after + WINDOW && attendance?.checkIn && !attendance?.checkOut) {
    return {
      title: "You’re still punched in",
      body: `Your shift ended at ${format12(shift.end)}. Punch out to record your hours.`,
    };
  }
  return null;
}

// Cheap pre-check before any reads: is this shift in a reminder window now?
function inReminderWindow(shift, nowMinutes) {
  const start = toMinutes(shift?.start), end = toMinutes(shift?.end);
  const inWindow = (from) => from != null && nowMinutes >= from && nowMinutes < from + WINDOW;
  return inWindow(start == null ? null : start - CHECK_IN_LEAD) || inWindow(end == null ? null : end + CHECK_OUT_AFTER);
}

module.exports = { reminderFor, inReminderWindow, format12, leaveCovers, toMinutes };
