.pragma library
// Handled paper (docs/OVERDRIVE.md §41; Claude B's own idea): each room's sheet wears with the time you have spent in
// it. Pure: no Qt, so Node tests run it (tests/test_paper.py). The journey (core/journey.py) keeps each room's seconds
// and visits, decayed by about a tenth a day, so the wear follows how you use the rooms now: a room you live in has
// handled paper, a room you've left alone goes back to crisp.
// - Thumbing: the corner you'd hold, the sheet's lower outer corner (away from the title's wedge), darkens.
// - Foxing: small rust spots, more as the sheet wears, gathered towards the margins, always in the same places for a
//   room (seeded by its id), so a room's sheet is recognisably its own.
// - A dog-ear at the upper outer corner once a room has been opened twenty times, larger with every doubling.

const HALF = 3 * 3600;       // s spent for the sheet to be about two-thirds worn
const SPOTS = 36;            // foxing spots on a fully worn sheet

function wear(seconds) {
    return seconds > 0 ? 1 - Math.exp(-seconds / HALF) : 0;
}

// A small seeded random generator (mulberry32) from a room id.
function rng(id) {
    let h = 1779033703;
    for (let i = 0; i < id.length; i++)
        h = Math.imul(h ^ id.charCodeAt(i), 3432918353), h = (h << 13) | (h >>> 19);
    let a = h >>> 0;
    return () => {
        a |= 0; a = (a + 0x6D2B79F5) | 0;
        let t = Math.imul(a ^ (a >>> 15), 1 | a);
        t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
        return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    };
}

// The foxing: [{x, y, r, a}] in a w × h sheet. The first spots of a room are always the same ones, and more appear as
// it wears (the list for a higher wear starts with the list for a lower one).
function spots(id, w, h, worn) {
    const next = rng(id), out = [];
    const n = Math.round(SPOTS * Math.max(0, Math.min(1, worn)));
    for (let i = 0; i < SPOTS; i++) {
        // Towards the margins: a coordinate pushed out from the centre.
        const u = next(), v = next(), size = next(), alpha = next();
        const push = t => t < 0.5 ? 0.5 * Math.pow(2 * t, 2.2) : 1 - 0.5 * Math.pow(2 * (1 - t), 2.2);
        if (i < n)
            out.push({ x: push(u) * w, y: push(v) * h, r: 0.8 + 3.2 * size * size, a: 0.18 + 0.3 * alpha });
    }
    return out;
}

// The thumbed corner's darkness (0–0.2) and reach (px).
function thumb(worn, w, h) {
    return { alpha: 0.2 * Math.max(0, Math.min(1, worn)), reach: Math.min(w, h) * (0.12 + 0.18 * worn) };
}

// The dog-ear's size (px): none under twenty visits, then 10 px, growing with each doubling, at most 44.
function dogEar(visits) {
    return visits >= 20 ? Math.min(44, Math.round(10 + 8 * Math.log2(visits / 20))) : 0;
}

// Cockled paper (docs/OVERDRIVE.md §47; B's own idea): paper cockles in the heat. The sheet's heat follows the processor's
// temperature with a two-minute thermal mass (it warms and cools slowly, so a hot spell stays a while); from 50 °C it
// cockles, fully at 90 °C: faint ripples at the house angle, and the sheet swells so its register marks move out.
const COOL = 50, HOT = 90, MASS = 120;
function heat(current, temp, dt) {
    if (typeof temp !== "number" || !Number.isFinite(temp))
        return current;
    return current + (temp - current) * (1 - Math.exp(-Math.max(0, dt) / MASS));
}
function cockle(h) {
    return Math.max(0, Math.min(1, (h - COOL) / (HOT - COOL)));
}
// The swell in px the register marks move out by.
function swell(c) {
    return Math.round(4 * c * 10) / 10;
}
// The ripples: [{offset, alpha}] bands across the sheet at the house angle, `period` px apart, alternately light and
// dark, as strong as the cockle.
function ripples(c, span, period) {
    const out = [];
    if (c <= 0.01)
        return out;
    for (let k = 0, o = 0; o < span; k++, o += period / 2)
        out.push({ offset: o, light: k % 2 === 0, alpha: 0.05 * c * (0.7 + 0.3 * Math.sin(k * 1.7)) });
    return out;
}
// The sheet's heat, kept for the session so a release and a new Overdrive don't forget a hot spell: {h (°C), at (ms)}.
const warmth = { h: NaN, at: 0 };
function warm(temp, now) {
    if (typeof temp !== "number" || !Number.isFinite(temp))
        return warmth.h;
    warmth.h = Number.isFinite(warmth.h) ? heat(warmth.h, temp, (now - warmth.at) / 1000) : temp;
    warmth.at = now;
    return warmth.h;
}
