.pragma library

// Workspaces as an orbit (Z209): the desks ride one tilted ring and the inspected one swings to the front.
// Pure layout, so tests can run it under Node. Angles are radians; the front of the ring is π/2 (nearest, lowest).

const FRONT = Math.PI / 2;
// The ring is seen from just above its plane: its height is this share of its width.
const TILT = 0.21;
// Desk sizes, as shares of the room's height: the front desk, and the far and near ends for the rest.
const FRONT_SIZE = 0.17;
const BACK_SIZE = 0.02;
const NEAR_SIZE = 0.055;
// An occupied desk is at least this much bigger than an empty one at the same depth.
const OCCUPIED_GAIN = 0.018;

// The turn to add so `from` swings to `to` the short way round a ring of `count`.
function shortest(from, to, count) {
    let d = ((to - from) % count + count) % count;
    if (d > count / 2) d -= count;
    return d;
}

// Where desk `index` (0-based) sits when the ring has turned by `turn` desks: angle, depth 0 (far) – 1 (near).
function place(index, turn, count) {
    const angle = FRONT + ((index - turn) / count) * 2 * Math.PI;
    return { angle: angle, depth: (Math.sin(angle) + 1) / 2, cos: Math.cos(angle), sin: Math.sin(angle) };
}

function ring(width) { return { rx: width, ry: width * TILT }; }

// A desk's diameter in px for a room `height` tall.
function size(depth, occupied, front, height) {
    if (front) return Math.round(height * FRONT_SIZE);
    return Math.round(height * (BACK_SIZE + (NEAR_SIZE - BACK_SIZE) * depth + (occupied ? OCCUPIED_GAIN : 0)));
}

// The desk's light: more windows burn hotter (index into Design.spectral, coolest last); -1 for an empty desk.
function warmth(windows, classes) {
    if (windows <= 0) return -1;
    return Math.max(0, classes - 1 - Math.min(windows, classes - 1));
}

// Where window `k` of `count` rides on the front desk's small orbit; depth 0 behind the desk, 1 in front.
function moon(k, count) {
    const angle = FRONT + (k / Math.max(1, count)) * 2 * Math.PI + 0.9;
    return { cos: Math.cos(angle), sin: Math.sin(angle), front: Math.sin(angle) > 0 };
}

// "2 windows · kitty, firefox" for a desk's windows ({ appId }), or "nothing open".
function summary(windows) {
    if (!windows.length) return "nothing open";
    const apps = [];
    for (const w of windows) { const a = w.appId || "window"; if (apps.indexOf(a) < 0) apps.push(a); }
    return windows.length + (windows.length === 1 ? " window · " : " windows · ") + apps.join(", ");
}

// The window a desk's strip starts on: the focused one, else the first.
function selected(windows) {
    const f = windows.findIndex(w => w.focused);
    return f >= 0 ? f : 0;
}
