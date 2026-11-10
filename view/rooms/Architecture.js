.pragma library

// Spectral architecture (atlas #67, docs/OVERDRIVE.md §20): Media's room is composed by the music. Pure: no Qt and
// no clock (times are passed in), so tests run it under Node (tests/test_architecture.py).
//
// The spectrum (the host's bins, 0–1) is folded into three broad bands. A section detector keeps a slow and a fast
// average of the bands' shares and loudness; when they part far enough, and not sooner than MIN_GAP after the last,
// a new section begins and the slow average jumps to the fast one. Each section is composed into columns across the
// room: bass-heavy music stands as one massive column, a dense bright passage fractures into many narrow cuts.

const SLOW = 8.0;        // s: the section's own average
const FAST = 1.5;        // s: what is playing now
const WARMUP = 1.5;      // s of sound before the first section is declared
const MIN_GAP = 6.0;     // s between sections at least
const THRESHOLD = 0.2;   // how far the fast profile must part from the slow one
const GAP = 0.012;       // between columns, as a share of the width

// [low, mid, high]: the means of the bottom sixth, the next third and the top half of the bins.
function bands(bins) {
    const n = Array.isArray(bins) ? bins.length : 0;
    if (n < 6)
        return [0, 0, 0];
    const mean = (a, b) => {
        let s = 0;
        for (let i = a; i < b; i++) s += Math.max(0, Math.min(1, Number(bins[i]) || 0));
        return s / Math.max(1, b - a);
    };
    const a = Math.max(1, Math.round(n / 6)), b = Math.max(a + 1, Math.round(n / 2));
    return [mean(0, a), mean(a, b), mean(b, n)];
}
function shares(b) {
    const sum = b[0] + b[1] + b[2];
    return sum > 1e-6 ? [b[0] / sum, b[1] / sum, b[2] / sum] : [1 / 3, 1 / 3, 1 / 3];
}

// The section detector: push(bins, t) returns the new section ({index, shares, loudness, t}) when one begins, else null.
function sections(options) {
    const o = Object.assign({ slow: SLOW, fast: FAST, warmup: WARMUP, gap: MIN_GAP, threshold: THRESHOLD }, options || {});
    let slow = null, fast = null, last = null, heard = 0, index = 0, previous = null;
    const blend = (avg, x, k) => avg.map((v, i) => v + (x[i] - v) * k);
    return {
        get index() { return index; },
        reset() { slow = fast = last = previous = null; heard = 0; index = 0; },
        push(bins, t) {
            const b = bands(bins), loud = b[0] + b[1] + b[2];
            const dt = previous === null ? 0 : Math.max(0, Math.min(1, t - previous));
            previous = t;
            if (loud < 0.02) return null;   // silence keeps the section
            const x = shares(b).concat([loud]);
            if (!slow) { slow = x.slice(); fast = x.slice(); heard = 0; }
            slow = blend(slow, x, 1 - Math.exp(-dt / o.slow));
            fast = blend(fast, x, 1 - Math.exp(-dt / o.fast));
            heard += dt;
            const distance = Math.abs(fast[0] - slow[0]) + Math.abs(fast[1] - slow[1]) + Math.abs(fast[2] - slow[2])
                + 0.5 * Math.abs(Math.log((fast[3] + 0.01) / (slow[3] + 0.01)));
            const first = last === null && heard >= o.warmup;
            const turn = last !== null && t - last >= o.gap && distance > o.threshold;
            if (!first && !turn) return null;
            last = t;
            slow = fast.slice();
            index += 1;
            return { index: index, shares: fast.slice(0, 3), loudness: fast[3], t: t };
        }
    };
}

// A small deterministic random sequence for a section's composition.
function rng(seed) {
    let s = (Math.abs(Math.floor(seed)) % 2147483646) + 1;
    return () => (s = (s * 16807) % 2147483647) / 2147483647;
}

// The columns for a section: [{x, w, role, slant}], x and w as shares of the width, left to right, filling it but for
// the gaps. Bass makes one column carry most of the width; brightness makes more, narrower cuts.
function compose(shares3, seed) {
    const [low, mid, high] = shares3;
    const n = Math.max(1, Math.min(11, Math.round(1 + 10 * Math.pow(high, 1.15) + 3 * mid * high)));
    const r = rng(seed * 7919 + 13);
    const massive = Math.floor(r() * n);
    const weights = [];
    for (let i = 0; i < n; i++)
        weights.push(i === massive ? 1 + 9 * low * low * n : 0.5 + r());
    const total = weights.reduce((a, w) => a + w, 0), free = 1 - GAP * (n - 1);
    const out = [];
    let x = 0;
    for (let i = 0; i < n; i++) {
        const w = free * weights[i] / total;
        out.push({ x: x, w: w, role: i === massive ? "ink" : r() < 0.25 ? "signal" : "paper", slant: r() < 0.5 ? 1 : 2 });
        x += w + GAP;
    }
    return out;
}

// Between two compositions at t ∈ [0, 1] (eased by the caller): columns are matched by order; extra ones grow from or
// shrink into the right edge.
function between(a, b, t) {
    if (t >= 1) return b.slice();
    if (t <= 0) return a.slice();
    const n = Math.max(a.length, b.length), out = [];
    for (let i = 0; i < n; i++) {
        const p = a[i] || { x: 1, w: 0, role: (b[i] || {}).role, slant: (b[i] || {}).slant };
        const q = b[i] || { x: 1, w: 0, role: p.role, slant: p.slant };
        out.push({ x: p.x + (q.x - p.x) * t, w: p.w + (q.w - p.w) * t, role: t < 0.5 ? p.role : q.role, slant: t < 0.5 ? p.slant : q.slant });
    }
    return out.filter(c => c.w > 0.0005);
}

// Silence geometry (atlas #70): near-silence held long enough snaps the room into exact registration, twelve equal
// columns on the grid with square edges, until sound comes back. hush(options).push(bins, t) is true while hushed.
const HUSH = 0.03;        // loudness (the three bands summed) under which it counts as quiet
const HUSH_AFTER = 1.2;   // s of quiet before the room registers
const HUSH_UNTIL = 0.25;  // s of sound before it lets go
function hush(options) {
    const o = Object.assign({ level: HUSH, after: HUSH_AFTER, until: HUSH_UNTIL }, options || {});
    let quietSince = null, loudSince = null, hushed = false;
    return {
        get hushed() { return hushed; },
        push(bins, t) {
            const b = bands(bins), loud = b[0] + b[1] + b[2];
            if (loud < o.level) {
                loudSince = null;
                if (quietSince === null) quietSince = t;
                if (!hushed && t - quietSince >= o.after) hushed = true;
            } else {
                quietSince = null;
                if (loudSince === null) loudSince = t;
                if (hushed && t - loudSince >= o.until) hushed = false;
            }
            return hushed;
        }
    };
}
function registered() {
    const n = 12, w = (1 - GAP * (n - 1)) / n, out = [];
    for (let i = 0; i < n; i++)
        out.push({ x: i * (w + GAP), w: w, role: "paper", slant: 0 });
    return out;
}
