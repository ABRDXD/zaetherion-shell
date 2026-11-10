.pragma library
// The harmonic typesetter (docs/OVERDRIVE.md §39; atlas #13). Pure: no Qt, so Node tests run it
// (tests/test_harmonic.py). The spectrum is the host's: 56 bins, 0–1, low to high.
//
// The track's title is re-set at each section change of the song, never in between, so it stays readable: the long-term
// spectrum (a six-second envelope) decides its shape. Bass broadens it (a horizontal stretch), a bright spectrum (a high
// centroid) leans it, loudness thickens it (Roboto Condensed's real cuts), dense mids tighten its tracking. A section
// change is the mean energy of the last four seconds moving by more than a third from the four before, at least eight
// seconds after the last one; a song that never changes is re-set every 40 s.

const TAU = 6;            // s, the envelope's time constant
const WINDOW = 4;         // s, each of the two windows a change compares
const CHANGE = 0.35;      // the relative move that is a section change
const MIN_GAP = 8;        // s between section changes
const MAX_GAP = 40;       // s before a re-set anyway

function clamp01(v) { return Math.max(0, Math.min(1, v)); }

// {low, mid, high, energy, centroid} of one spectrum frame; low/mid/high are shares of the energy.
function bands(spectrum) {
    const s = spectrum ?? [], n = s.length;
    if (!n)
        return { low: 0, mid: 0, high: 0, energy: 0, centroid: 0 };
    const lowEnd = Math.round(n * 0.16), midEnd = Math.round(n * 0.5);
    let low = 0, mid = 0, high = 0, weighted = 0;
    for (let i = 0; i < n; i++) {
        const v = Math.max(0, s[i]);
        if (i < lowEnd) low += v; else if (i < midEnd) mid += v; else high += v;
        weighted += v * i;
    }
    const total = low + mid + high;
    if (total <= 0)
        return { low: 0, mid: 0, high: 0, energy: 0, centroid: 0 };
    return { low: low / total, mid: mid / total, high: high / total, energy: total / n, centroid: weighted / total / Math.max(1, n - 1) };
}

// The envelope after `dt` s of a frame: each field eased toward the frame's.
function ease(env, frame, dt) {
    if (!env)
        return Object.assign({}, frame);
    const k = 1 - Math.exp(-Math.max(0, dt) / TAU), out = {};
    for (const key of ["low", "mid", "high", "energy", "centroid"])
        out[key] = env[key] + (frame[key] - env[key]) * k;
    return out;
}

// The title's set from an envelope: {stretch, slant, weight, tracking}.
function typeset(env) {
    const e = env ?? { low: 0, mid: 0, high: 0, energy: 0, centroid: 0 };
    const weights = [300, 400, 500, 700];
    return {
        stretch: Math.round((0.9 + 0.3 * clamp01((e.low - 0.15) / 0.5)) * 1000) / 1000,
        slant: -Math.round(0.28 * clamp01((e.centroid - 0.2) / 0.4) * 1000) / 1000,
        weight: weights[Math.min(3, Math.floor(clamp01(e.energy / 0.45) * 4))],
        tracking: Math.round((2 - 5 * clamp01((e.mid - 0.25) / 0.4)) * 10) / 10
    };
}

// Energy samples [{t, e}] kept for two windows.
function keep(history, t, e) {
    return history.concat([{ t: t, e: e }]).filter(h => t - h.t <= 2 * WINDOW);
}
// Whether `t` is a section change, given the samples and when the last one was.
function boundary(history, t, last) {
    if (t - last < MIN_GAP)
        return false;
    if (t - last >= MAX_GAP)
        return true;
    const recent = history.filter(h => t - h.t < WINDOW), before = history.filter(h => t - h.t >= WINDOW);
    if (recent.length < 3 || before.length < 3)
        return false;
    const mean = a => a.reduce((s, h) => s + h.e, 0) / a.length;
    const a = mean(recent), b = mean(before);
    return Math.abs(a - b) / Math.max(b, 0.02) > CHANGE;
}
