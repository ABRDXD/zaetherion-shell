.pragma library
// Performance's record as the scheduler's ground (docs/OVERDRIVE.md §37; atlas #15, #72). Pure: no Qt, so Node tests
// run it (tests/test_plates.py).
//
// Scheduling fault lines (#15): each processor core is a plate. The plates are a power diagram (a weighted Voronoi) of
// one seed per core on a jittered grid; a core's weight is how much busier it is than the others, so a busy core's plate
// pushes its faults outward into its idle neighbours' and the faults migrate as the load moves. When more processes
// want to run than there are cores (runnable pressure), the faults are under stress and slip: each is drawn twice, its
// two sides thrown apart. The faults' past positions stay as faint scarps (a few, a few seconds apart).
// Context-switch weave (#72): voluntary switches (a process waiting: input, disk, a lock) and involuntary ones (a
// process preempted: contention) are two families of threads crossing the record. Each family is as dense as the log of
// its rate; the voluntary threads lean at the house angle (78°) and the involuntary ones open away from them by 12° plus
// up to 66° more as preemption takes the larger share, so a calm machine's weave is nearly a single grain and a contended
// one a tight twill. The threads slide along by how many switches went by.

const SCARPS = 6;

function clamp01(v) { return Math.max(0, Math.min(1, v)); }

// A small deterministic hash in [0, 1).
function jitter(i, k) {
    const s = Math.sin((i + 1) * 12.9898 + k * 78.233) * 43758.5453;
    return s - Math.floor(s);
}

// One seed per core on a grid shaped like the rect, each moved up to a quarter cell. Returns {seeds: [{x, y}], cell}.
function seeds(n, w, h) {
    if (n <= 0 || w <= 0 || h <= 0)
        return { seeds: [], cell: 0 };
    const cols = Math.max(1, Math.round(Math.sqrt(n * w / h))), rows = Math.ceil(n / cols);
    const cw = w / cols, ch = h / rows, out = [];
    for (let i = 0; i < n; i++) {
        const c = i % cols, r = Math.floor(i / cols);
        // The last row's seeds spread across the width.
        const inRow = r === rows - 1 ? n - cols * (rows - 1) : cols;
        const x = (c + 0.5) * w / inRow + (jitter(i, 1) - 0.5) * 0.5 * (w / inRow);
        const y = (r + 0.5) * ch + (jitter(i, 2) - 0.5) * 0.5 * ch;
        out.push({ x: x, y: y });
    }
    return { seeds: out, cell: Math.min(cw, ch) };
}

// Weights from the cores' busy shares: how much busier each is than the mean, times the cell's area, capped so no plate
// is squeezed out.
function weights(loads, cell) {
    if (!loads.length)
        return [];
    const mean = loads.reduce((s, l) => s + l, 0) / loads.length;
    return loads.map(l => Math.max(-0.45, Math.min(0.45, (l - mean) * 0.9)) * cell * cell);
}

// Sutherland–Hodgman: the part of `poly` where a·x + b·y ≤ c.
function clip(poly, a, b, c) {
    const out = [];
    for (let i = 0; i < poly.length; i++) {
        const p = poly[i], q = poly[(i + 1) % poly.length];
        const fp = a * p.x + b * p.y - c, fq = a * q.x + b * q.y - c;
        if (fp <= 0)
            out.push(p);
        if ((fp < 0 && fq > 0) || (fp > 0 && fq < 0)) {
            const t = fp / (fp - fq);
            out.push({ x: p.x + t * (q.x - p.x), y: p.y + t * (q.y - p.y) });
        }
    }
    return out;
}

// The power diagram's cells in the rect [0, w] × [0, h]: cell i is where |x − pi|² − wi ≤ |x − pj|² − wj for every j,
// that is 2(pj − pi)·x ≤ |pj|² − |pi|² − wj + wi.
function cells(points, ws, w, h) {
    return points.map((p, i) => {
        let poly = [{ x: 0, y: 0 }, { x: w, y: 0 }, { x: w, y: h }, { x: 0, y: h }];
        for (let j = 0; j < points.length && poly.length; j++) {
            if (j === i)
                continue;
            const q = points[j];
            poly = clip(poly, 2 * (q.x - p.x), 2 * (q.y - p.y), q.x * q.x + q.y * q.y - p.x * p.x - p.y * p.y - ws[j] + ws[i]);
        }
        return poly;
    });
}

function area(poly) {
    let a = 0;
    for (let i = 0; i < poly.length; i++) {
        const p = poly[i], q = poly[(i + 1) % poly.length];
        a += p.x * q.y - q.x * p.y;
    }
    return Math.abs(a) / 2;
}
function centroid(poly) {
    const n = Math.max(1, poly.length);
    return { x: poly.reduce((s, p) => s + p.x, 0) / n, y: poly.reduce((s, p) => s + p.y, 0) / n };
}
// The largest plate's index.
function largest(polys) {
    let best = -1, most = -1;
    polys.forEach((p, i) => { const a = area(p); if (a > most) { most = a; best = i; } });
    return best;
}

// The faults' stress, 0–1: the runnable processes past one per core (a full queue on every core is 1).
function stress(runnable, cores) {
    return cores > 0 ? clamp01((runnable - 1) / cores) : 0;
}
// How far a stressed fault's two sides are thrown apart, in px.
function throwOf(s) {
    return s > 0.15 ? 1 + 5 * s : 0;
}

// The scarps: the faults' recent positions, newest last, at most SCARPS, one taken every `every` s.
function scarp(kept, polys, now, every) {
    const last = kept.length ? kept[kept.length - 1] : null;
    if (last && now - last.at < every)
        return kept;
    return kept.concat([{ at: now, polys: polys }]).slice(-SCARPS);
}

// The weave: threads per family and their angles (degrees from the horizontal).
function weave(voluntary, involuntary) {
    const v = Math.max(0, voluntary), n = Math.max(0, involuntary);
    const count = r => Math.min(28, Math.round(Math.log10(1 + r) * 6));
    const share = v + n > 0 ? n / (v + n) : 0;
    return { voluntary: count(v), involuntary: count(n), share: share, angleV: 78, angleI: 78 - (12 + 66 * clamp01(share * 2)) };
}

// `count` parallel threads at `angle` across [0, w] × [0, h], evenly spaced, slid by `phase` (0–1 of a spacing): each a
// segment [x1, y1, x2, y2] clipped to the rect.
function threads(count, angle, phase, w, h) {
    if (count <= 0 || w <= 0 || h <= 0)
        return [];
    const a = angle * Math.PI / 180, dx = Math.cos(a), dy = -Math.sin(a), nx = -dy, ny = dx;
    const corners = [[0, 0], [w, 0], [w, h], [0, h]].map(c => c[0] * nx + c[1] * ny);
    const lo = Math.min(...corners), hi = Math.max(...corners), step = (hi - lo) / count;
    const out = [];
    for (let k = 0; k < count; k++) {
        const o = lo + (k + 0.5 + (phase % 1)) * step;
        // The line {p : p·n = o}, through o·n, along d; clipped to the rect by its parameter range.
        const px = o * nx, py = o * ny;
        let t0 = -Infinity, t1 = Infinity;
        for (const [p, d, min, max] of [[px, dx, 0, w], [py, dy, 0, h]]) {
            if (Math.abs(d) < 1e-9) {
                if (p < min || p > max) { t0 = 1; t1 = 0; }
                continue;
            }
            const a1 = (min - p) / d, a2 = (max - p) / d;
            t0 = Math.max(t0, Math.min(a1, a2));
            t1 = Math.min(t1, Math.max(a1, a2));
        }
        if (t1 > t0)
            out.push([px + t0 * dx, py + t0 * dy, px + t1 * dx, py + t1 * dy]);
    }
    return out;
}
