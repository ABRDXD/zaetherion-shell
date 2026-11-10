.pragma library
// The night log (docs/OVERDRIVE.md §48; Claude B's own idea): each night the field archive is opened (22:00–05:59, its
// fiction on), the surveyor logs the moon: its age in the mean synodic month (from the new moon of 6 January 2000,
// 18:14 UTC), how much of it is lit and the phase's name. One entry a night, the night named by its evening; thirty
// kept. Pure: no Qt, so Node tests run it (tests/test_night_log.py). The moon is not the user's system: the archive's
// promise holds.

const SYNODIC = 29.530588853;                  // days
const EPOCH = Date.UTC(2000, 0, 6, 18, 14);    // a new moon
const KEEP = 30;

// The moon's age at a time (ms), 0–1 of a lunation.
function age(ms) {
    const days = (ms - EPOCH) / 86400000;
    return ((days / SYNODIC) % 1 + 1) % 1;
}
function lit(a) {
    return (1 - Math.cos(2 * Math.PI * a)) / 2;
}
function phase(a) {
    const names = ["NEW", "WAXING CRESCENT", "FIRST QUARTER", "WAXING GIBBOUS", "FULL", "WANING GIBBOUS", "LAST QUARTER", "WANING CRESCENT"];
    return names[Math.floor(((a * 8) + 0.5) % 8)];
}
// The night a time belongs to: its evening's date ("2026-11-09" for 23:00 on the 9th and 02:00 on the 10th).
function night(date) {
    const d = new Date(date.getFullYear(), date.getMonth(), date.getDate() - (date.getHours() < 6 ? 1 : 0));
    return d.getFullYear() + "-" + String(d.getMonth() + 1).padStart(2, "0") + "-" + String(d.getDate()).padStart(2, "0");
}
function isNight(date) {
    const h = date.getHours();
    return h >= 22 || h < 6;
}
// The log after an opening at `date`: a new entry {night, at: "23:14", age} for a night not logged yet.
function log(entries, date) {
    const list = Array.isArray(entries) ? entries : [];
    if (!isNight(date))
        return list;
    const key = night(date);
    if (list.some(e => e.night === key))
        return list;
    const at = String(date.getHours()).padStart(2, "0") + ":" + String(date.getMinutes()).padStart(2, "0");
    return list.concat([{ night: key, at: at, age: Math.round(age(date.getTime()) * 1000) / 1000 }]).slice(-KEEP);
}
// The line the archive prints for an entry.
function line(e) {
    return e.night + " " + e.at + " · " + phase(e.age) + " · " + Math.round(100 * lit(e.age)) + "% LIT";
}
// Only well-formed entries survive a load.
function clean(entries) {
    return (Array.isArray(entries) ? entries : []).filter(e => e && /^\d{4}-\d{2}-\d{2}$/.test(e.night) && /^\d{2}:\d{2}$/.test(e.at)
        && typeof e.age === "number" && e.age >= 0 && e.age < 1).slice(-KEEP);
}
