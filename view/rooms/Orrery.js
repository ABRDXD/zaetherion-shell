.pragma library

// The telemetry orrery (M12): the laws under Performance's Overdrive orrery. No QML, no clock: times are passed
// in (seconds of the orrery's own clock, which slows with the engine), so tests run it under Node
// (tests/test_orrery_laws.py). A sample is core/orrery.py's answer to `orrery.sample`.
//
// The laws, each caused by a real reading:
// - mass is memory: a body's volume is its resident memory (its radius the cube root);
// - speed is CPU: a turn every 8 s at one whole core, and an idle process stands still;
// - altitude is memory's history: heavier sits deeper, and a growing process sinks below its place, so a leak
//   spirals in; a shrinking one rises. Below altitude 0 is the Roche limit, where a body is torn into debris;
// - a new process falls in from outside and is captured; an ended one leaves its ring behind, fading;
// - every fork the kernel counts is a meteor falling into the sun;
// - the busiest body trails a comet tail pointing away from the sun, as long as it is busy.

const TURN = 8;               // seconds per turn at 100 % of one core
const LIGHT = 64;             // MiB: at or under this, a body floats at the top (altitude 1)…
const HEAVY = 4096;           // …and at this, it sits on the Roche limit (altitude 0)
const DRIFT = 1;              // MiB/s of growth that pulls a body tanh(1) of PULL down
const PULL = 0.34;            // the most growth (or shrinking) can move a body, in altitude
const SETTLE = 2.4;           // seconds: how quickly a body reaches a new altitude
const FALL = 0.55;            // seconds: the capture's decay…
const RING = 2.6;             // …and its swing (rad/s), so a new body overshoots once and settles
const ENTRY = 1.75;           // the altitude a new process falls in from
const ROCHE = -0.04;          // below this, debris
const STEER = 0.015;          // a new place nearer than this to the old one waits
const FADE = 1.0;             // seconds a body takes to fade in or out
const RING_LIFE = 8;          // seconds an ended body's ring and name stay
const METEOR_LIFE = 0.9;      // seconds a meteor takes to fall
const METEORS_PER_SAMPLE = 8; // at most this many meteors a second; beyond, each one stands for more forks
const COMET_MIN = 5;          // % of a core: the busiest body grows a tail from here
const SLOTS = 24;             // core/orrery.py's KEEP

function clamp(v, lo, hi) { return Math.max(lo, Math.min(hi, v)); }

// Half-size in px for resident memory in MiB: the cube root, so 4 GiB is ~7× 12 MiB, not 340×.
function size(rss) {
    return clamp(1.05 * Math.cbrt(Math.max(0, rss)), 2, 18);
}

// Angular speed (rad/s) for CPU in % of one core.
function omega(cpu) {
    return 2 * Math.PI / TURN * Math.max(0, cpu) / 100;
}

// Where a body belongs: 1 at the top, 0 on the Roche limit, below it when growing fast enough.
function altitude(rss, growth) {
    const depth = Math.log2(Math.max(rss, LIGHT) / LIGHT) / Math.log2(HEAVY / LIGHT);
    return 1 - clamp(depth, 0, 1) - PULL * Math.tanh((growth || 0) / DRIFT);
}

// A body's altitude at time t: an exponential approach (a spiral, since it keeps orbiting), or for a captured
// body a damped swing, so it falls past its ring once and settles.
function altAt(b, t) {
    const s = Math.max(0, t - b.altSince);
    const d = b.altFrom - b.alt;
    return b.alt + d * (b.capture ? Math.exp(-s / FALL) * Math.cos(RING * s) : Math.exp(-s / (SETTLE / 3)));
}

function angleAt(b, t) {
    return b.theta + b.omega * (t - b.since);
}

// How present a body is (0–1): fading in after it appears, out after it leaves the shown set.
function presence(b, t) {
    const into = b.capture ? 1 : clamp((t - b.born) / FADE, 0, 1);
    return b.gone === null ? into : into * clamp(1 - (t - b.gone) / FADE, 0, 1);
}

// The orrery's frame: centre (cx, cy), the outer ring's semi-major axis `outer` (altitude 1), the Roche ring's
// `inner` (altitude 0), the rings' minor/major ratio and the plane's lean (rad from vertical, the house's 78°).
function geometry(width, height) {
    const outer = Math.max(40, height / 2 - 26);
    return { cx: width / 2, cy: height / 2, outer: outer, inner: outer * 0.42, aspect: 0.5, lean: 12 * Math.PI / 180 };
}

// The ring's semi-major axis at an altitude. Inside the Roche limit the rings close in on the sun at half rate.
function radiusAt(g, alt) {
    const a = clamp(alt, -0.6, 1.2);
    return a >= 0 ? g.inner + (g.outer - g.inner) * a : g.inner * (1 + a * 0.5);
}

// A point at altitude `alt`, angle `theta` on the leaning plane. depth: 1 nearest the viewer (the right-hand
// side of the ring, θ = 0), 0 furthest.
function place(g, alt, theta) {
    const a = radiusAt(g, alt), b = a * g.aspect;
    const u = b * Math.cos(theta), v = a * Math.sin(theta);
    const s = Math.sin(g.lean), c = Math.cos(g.lean);
    return { x: g.cx + u * c + v * s, y: g.cy + u * s - v * c, depth: (1 + Math.cos(theta)) / 2 };
}

function hash(text) {
    let h = 2166136261;
    for (let i = 0; i < text.length; i++) h = Math.imul(h ^ text.charCodeAt(i), 16777619);
    return (h >>> 0) / 4294967296;
}

// One sample into the orrery's state at time t. state: { slots: [body|null] × SLOTS, rings: [], meteors: [] }.
// A body keeps its slot for life, so its delegate never jumps. Returns the next state (nothing is mutated).
function merge(state, sample, t) {
    const slots = (state.slots || []).slice();
    while (slots.length < SLOTS) slots.push(null);
    const rings = (state.rings || []).filter(r => t - r.at < RING_LIFE);
    const meteors = (state.meteors || []).filter(m => t - m.at < METEOR_LIFE);
    if (!sample || !sample.running) return { slots: slots.map(() => null), rings: [], meteors: [] };
    const incoming = {};
    for (const b of sample.bodies || []) incoming[b.id] = b;
    const exited = {};
    for (const e of sample.exits || []) exited[e.id] = e;
    let busiest = null;
    for (const b of sample.bodies || [])
        if (b.cpu >= COMET_MIN && (!busiest || b.cpu > busiest.cpu)) busiest = b;
    // Bodies already here: re-based to the new speed at t (so nothing jumps), steered to the new altitude.
    for (let i = 0; i < slots.length; i++) {
        const old = slots[i];
        if (!old) continue;
        if (old.gone !== null) {
            if (t - old.gone >= FADE) slots[i] = null;
            continue;
        }
        const next = incoming[old.id];
        const body = Object.assign({}, old);
        if (!next) {
            if (exited[old.id]) {
                rings.push({ alt: altAt(old, t), name: old.name, at: t, theta: angleAt(old, t), size: old.size });
                slots[i] = null;
            } else {
                body.gone = t;
                body.theta = angleAt(old, t); body.since = t; body.omega = 0;
                slots[i] = body;
            }
            continue;
        }
        const now = altAt(old, t);
        const target = altitude(next.rss, next.growth);
        body.theta = angleAt(old, t); body.since = t; body.omega = omega(next.cpu);
        // Small changes of place wait until they add up, so a body doesn't wobble with every sample.
        if (Math.abs(target - old.alt) > STEER) {
            body.altFrom = now; body.alt = target; body.altSince = t; body.capture = false;
        }
        body.cpu = next.cpu; body.rss = next.rss; body.growth = next.growth; body.size = size(next.rss);
        body.comet = busiest !== null && busiest.id === old.id;
        slots[i] = body;
        delete incoming[old.id];
    }
    // New bodies take free slots, heaviest first. A born process falls in from outside; one that only grew
    // into the shown set fades in where it belongs.
    const fresh = (sample.bodies || []).filter(b => incoming[b.id]);
    for (const b of fresh) {
        const free = slots.indexOf(null);
        if (free < 0) break;
        const target = altitude(b.rss, b.growth);
        slots[free] = {
            id: b.id, name: b.name, pid: b.pid, cpu: b.cpu, rss: b.rss, growth: b.growth, size: size(b.rss),
            theta: 2 * Math.PI * hash(b.id), omega: omega(b.cpu), since: t,
            alt: target, altFrom: b.born ? ENTRY : target, altSince: t, capture: !!b.born,
            born: t, gone: null, comet: busiest !== null && busiest.id === b.id
        };
    }
    // Forks: one meteor each, up to METEORS_PER_SAMPLE, spread over the coming second.
    const forks = Math.max(0, sample.forks || 0);
    const count = Math.min(forks, METEORS_PER_SAMPLE);
    for (let k = 0; k < count; k++) {
        const seed = hash(String(sample.at) + ":" + k);
        meteors.push({ at: t + seed * 0.9, angle: 2 * Math.PI * hash(seed + "a"), stands: Math.ceil(forks / count) });
    }
    return { slots: slots, rings: rings.slice(-6), meteors: meteors.slice(-24) };
}

// A meteor's place: it falls from beyond the outer ring towards the sun under constant pull, vanishing at the
// Roche ring. null before it starts or after it lands.
function meteorAt(g, m, t) {
    const s = (t - m.at) / METEOR_LIFE;
    if (s < 0 || s > 1) return null;
    const from = g.outer * 1.35, to = g.inner * 0.9;
    const r = from - (from - to) * s * s;
    const dx = Math.cos(m.angle), dy = Math.sin(m.angle);
    return { x: g.cx + dx * r, y: g.cy + dy * r * 0.8, angle: Math.atan2(-dy * 0.8, -dx), life: s };
}

// The comet's tail: from the body, straight away from the sun, longer the busier it is.
function tail(g, p, cpu) {
    const dx = p.x - g.cx, dy = p.y - g.cy;
    return { angle: Math.atan2(dy, dx), length: 14 + 70 * clamp(cpu / 100, 0, 1.5) };
}

function roche(alt) {
    return alt < ROCHE;
}
