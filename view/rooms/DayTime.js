.pragma library

// Home's day ruler (docs/OVERDRIVE.md §21; atlas #65, #63, W4): pure, no Qt and no clock, so tests run it under Node
// (tests/test_day_ruler.py). Hours are local civil hours, 0–24.
//
// Day-length compression (#65): the ruler always labels civil hours, but the day (sunrise to sunset) takes DAY of its
// width and the night the rest, split between morning and evening. So a winter's few daylight hours are drawn wide and
// a summer's many are packed close: the season changes the ruler's segmentation, not its labels.
// Sidereal margin (#63): a second row of ticks at each sidereal hour, which come about four minutes earlier every day.
// Misregistration (W4): the same moment in three frames, civil, solar and sidereal, all correct, all apart.

const DAY = 0.6;
const SIDEREAL_RATE = 1.00273790935;   // sidereal hours per civil hour

function wrap(h) {
    return ((h % 24) + 24) % 24;
}

// The ruler's x (0–1) for civil hour h, given today's sunrise and sunset (hours). With no sunrise or sunset (a polar
// day or night, or no sky yet) the ruler is linear.
function x(h, rise, set) {
    h = Math.max(0, Math.min(24, h));
    if (!(rise >= 0 && set > rise && set <= 24))
        return h / 24;
    const night = 1 - DAY, morning = night * rise / (24 - (set - rise)), evening = night - morning;
    if (h < rise)
        return morning * h / rise;
    if (h < set)
        return morning + DAY * (h - rise) / (set - rise);
    return morning + DAY + evening * (h - set) / (24 - set);
}

// The civil hour ticks: [{h, x, major, label}], major every six hours.
function ticks(rise, set) {
    const out = [];
    for (let h = 0; h <= 24; h++)
        out.push({ h: h, x: x(h, rise, set), major: h % 6 === 0, label: h % 6 === 0 && h < 24 ? String(h).padStart(2, "0") : "" });
    return out;
}

// The sidereal hour ticks over today's civil day: each sidereal hour k falls at the civil hour when local sidereal time
// reads k. `now` is the civil hour now and `lst` the local sidereal time now, in hours. [{k, h, x}]
function siderealTicks(now, lst, rise, set) {
    const out = [];
    for (let k = 0; k < 24; k++) {
        // The next time it reads k, folded into today's 24 hours (a tick already passed is drawn where it comes back).
        const h = wrap(now + wrap(k - lst) / SIDEREAL_RATE);
        out.push({ k: k, h: h, x: x(h, rise, set) });
    }
    return out.sort((a, b) => a.h - b.h);
}

// Apparent solar time (hours): noon when the sun is highest, the midpoint of sunrise and sunset.
function solar(now, rise, set) {
    if (!(rise >= 0 && set > rise))
        return now;
    return wrap(12 + now - (rise + set) / 2);
}

// The moment in three frames, for the misregistration: [{frame, h, x}], civil first.
function frames(now, lst, rise, set) {
    return [
        { frame: "CIVIL", h: now, x: x(now, rise, set) },
        { frame: "SOLAR", h: solar(now, rise, set), x: x(solar(now, rise, set), rise, set) },
        { frame: "SIDEREAL", h: wrap(lst), x: x(wrap(lst), rise, set) }
    ];
}

// "07:42" for an hour.
function hhmm(h) {
    const m = Math.round(wrap(h) * 60) % 1440;
    return String(Math.floor(m / 60)).padStart(2, "0") + ":" + String(m % 60).padStart(2, "0");
}

// Recurrence windows (atlas #66): hours of the day when a room keeps being opened. The journey (core/journey.py) gives
// each room's visits by hour, scaled so its busiest hour is 1. A room visited at least MIN_VISITS times has a window
// over each hour at STRONG or more: [{room, number, h}], at most MAX of them, the strongest first. It predicts and
// nags about nothing; it only shows the habit.
const ROOMS = ["home", "media", "performance", "workspaces", "devices", "tasks", "timers", "clipboard", "notifications", "codex"];
const STRONG = 0.75;
const MIN_VISITS = 6;
const MAX = 6;
function recurrence(journey) {
    const hours = journey?.hours || {}, visits = journey?.visits || {}, out = [];
    for (const room of Object.keys(hours)) {
        const n = ROOMS.indexOf(room);
        if (n < 0 || (visits[room] || 0) < MIN_VISITS || !Array.isArray(hours[room]))
            continue;
        hours[room].forEach((v, h) => { if (v >= STRONG) out.push({ room: room, number: String(n).padStart(2, "0"), h: h, v: v }); });
    }
    return out.sort((a, b) => b.v - a.v || a.h - b.h).slice(0, MAX).map(w => ({ room: w.room, number: w.number, h: w.h }));
}
