.pragma library
// The room titles as type under load (docs/OVERDRIVE.md §35; atlas #41–44). Pure rules for view/shell/LiveTitle:
// the room's content presses on the title wedge, and the title answers in its own anatomy.
// - Load-bearing glyphs (#41): each glyph carries the content beside it (the share of its band of the sheet's
//   height that the room's ink covers); a loaded glyph is set heavier and compressed into the beam, an idle one
//   light. The glyph with the most load is the bearing, marked on the wedge's inner edge.
// - Data kerning (#42): the tracking is the room's pressure, read once, on entry: tight when the room holds
//   more than it shows, open when it is nearly empty.
// - Phase change (#44): past a pressure threshold the title stops being editorial and becomes an instrument
//   (mono cells on a tick scale), glyph by glyph outward from the bearing; it goes back only well below the
//   threshold. Crossings are remembered for the session, per room, and counted on the instrument.
// - Counter windows (#43): the enclosed counters of the glyphs (A, O, R, P, D, B …) are found from the drawn
//   type itself and become windows onto what the room holds below the fold.

const WEIGHTS = [300, 400, 500, 700];          // Light, Regular, Medium, Bold: Roboto Condensed's real cuts
const LOAD_STEPS = [0.06, 0.16, 0.32];         // a glyph's load at which it moves to the next weight
const SQUASH = 0.07;                           // a fully loaded glyph is 7 % shorter into the beam…
const SPREAD = 0.05;                           // …and 5 % wider along it
const ENTER = 0.72;                            // pressure at which the title turns instrument
const LEAVE = 0.58;                            // and below which it turns back
const STAGGER = 45;                            // ms between glyphs as the phase front runs out from the bearing
const DENSE = 0.42;                            // the ink share of a packed room: density 1

function clamp01(v) { return Math.max(0, Math.min(1, v)); }

// The share of [y0, y1] that the rects cover, by area, across `width`. Rects are {x, y, width, height}.
function bandLoad(rects, y0, y1, width) {
    const lo = Math.min(y0, y1), hi = Math.max(y0, y1);
    if (hi - lo <= 0 || width <= 0)
        return 0;
    let area = 0;
    for (const r of rects) {
        const over = Math.min(hi, r.y + r.height) - Math.max(lo, r.y);
        if (over > 0)
            area += over * Math.max(0, r.width);
    }
    return clamp01(area / ((hi - lo) * width));
}

// One load per glyph band ([[y0, y1], …]).
function loads(rects, bands, width) {
    return bands.map(b => bandLoad(rects, b[0], b[1], width));
}

function weightFor(load) {
    let i = 0;
    while (i < LOAD_STEPS.length && load >= LOAD_STEPS[i])
        i++;
    return WEIGHTS[i];
}

// A glyph's scale under its load: {along, across} (along the reading direction, and into the beam).
function squash(load) {
    const l = clamp01(load);
    return { along: 1 + SPREAD * l, across: 1 - SQUASH * l };
}

// The bearing: the most loaded glyph, or -1 if nothing rests on the title.
function bearing(glyphLoads) {
    let best = -1, most = 0.02;
    glyphLoads.forEach((l, i) => { if (l > most) { most = l; best = i; } });
    return best;
}

// The room's pressure, 0–1: half how far it overflows (three screens or more is full), half how dense its ink is.
function pressure(contentHeight, viewportHeight, inkShare) {
    const overflow = viewportHeight > 0 ? clamp01((contentHeight / viewportHeight - 1) / 2) : 0;
    return clamp01(0.5 * overflow + 0.5 * clamp01(inkShare / DENSE));
}

// Tracking in px for a name set at `size`: +8 % of the size when empty, −4 % at full pressure.
function tracking(p, size) {
    return Math.round(size * (0.08 - 0.12 * clamp01(p)) * 10) / 10;
}

// Hysteresis: editorial → instrument at ENTER, back at LEAVE.
function phase(instrument, p) {
    return instrument ? p >= LEAVE : p >= ENTER;
}

// The delay before glyph i changes phase, the front running out from the nucleus (the bearing, or the first glyph).
function delay(i, nucleus) {
    return Math.abs(i - Math.max(0, nucleus)) * STAGGER;
}

// The session's memory, per room: crossings into the instrument phase. Not saved; gone when FART exits.
const memory = {};
function cross(room) {
    memory[room] = (memory[room] ?? 0) + 1;
    return memory[room];
}
function crossings(room) {
    return memory[room] ?? 0;
}

// The glyphs' places along the line: x of each glyph's origin, from advances and tracking.
function places(advances, track) {
    const out = [];
    let x = 0;
    for (const a of advances) {
        out.push(x);
        x += a + track;
    }
    return out;
}
function length(advances, track) {
    return advances.reduce((s, a) => s + a, 0) + track * Math.max(0, advances.length - 1);
}

// Counters: the transparent pixels the outside can't reach. `alpha` is a flat array of w × h alpha values
// (0–255); returns a Uint8Array with 1 where a pixel is inside a counter (enclosed, at least `min` pixels big).
function counters(alpha, w, h, min) {
    const n = w * h, outside = new Uint8Array(n), stack = [];
    const open = i => alpha[i] < 128;
    const push = i => { if (!outside[i] && open(i)) { outside[i] = 1; stack.push(i); } };
    for (let x = 0; x < w; x++) { push(x); push((h - 1) * w + x); }
    for (let y = 0; y < h; y++) { push(y * w); push(y * w + w - 1); }
    while (stack.length) {
        const i = stack.pop(), x = i % w;
        if (x > 0) push(i - 1);
        if (x < w - 1) push(i + 1);
        if (i >= w) push(i - w);
        if (i < n - w) push(i + w);
    }
    // What's left open is enclosed. Drop specks (anti-aliasing seams) smaller than `min`.
    const inside = new Uint8Array(n), seen = new Uint8Array(n);
    for (let s = 0; s < n; s++) {
        if (seen[s] || outside[s] || !open(s))
            continue;
        const region = [s];
        seen[s] = 1;
        for (let k = 0; k < region.length; k++) {
            const i = region[k], x = i % w;
            for (const j of [x > 0 ? i - 1 : -1, x < w - 1 ? i + 1 : -1, i >= w ? i - w : -1, i < n - w ? i + w : -1])
                if (j >= 0 && !seen[j] && !outside[j] && open(j)) { seen[j] = 1; region.push(j); }
        }
        if (region.length >= min)
            for (const i of region)
                inside[i] = 1;
    }
    return inside;
}
// How many counters there are (4-connected regions of `inside`).
function count(inside, w, h) {
    const seen = new Uint8Array(w * h);
    let regions = 0;
    for (let s = 0; s < w * h; s++) {
        if (!inside[s] || seen[s])
            continue;
        regions++;
        const stack = [s];
        seen[s] = 1;
        while (stack.length) {
            const i = stack.pop(), x = i % w;
            for (const j of [x > 0 ? i - 1 : -1, x < w - 1 ? i + 1 : -1, i >= w ? i - w : -1, i < w * h - w ? i + w : -1])
                if (j >= 0 && inside[j] && !seen[j]) { seen[j] = 1; stack.push(j); }
        }
    }
    return regions;
}
