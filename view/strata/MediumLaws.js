.pragma library
// How each room pushes the Medium (docs/OVERDRIVE.md §34). A law is a pure function of the room, the time and what the room already knows; it returns at most eight
// emitters for view/strata/Medium.qml. Positions are 0..1 across the panel, y down. Only counts and levels come in here, never anyone's content.
const MAX = 8;
function clamp(x, lo, hi) { return Math.max(lo, Math.min(hi, x)); }
function jet(x, y, r, vx, vy, force, smoke, heat, second) {
    return { x: x, y: y, r: r, push: [vx, vy], force: force, smoke: smoke, heat: heat, second: second };
}
const LAWS = {
    // The day breathing: two slow lungs either side of the clock.
    home(t) {
        const b = 0.5 + 0.5 * Math.sin(t * 0.5);
        return [jet(0.3, 0.72 + 0.04 * Math.sin(t * 0.31), 0.09, 0.2, -0.5, 0.05 + 0.05 * b, 0.007, 0.002, 0),
                jet(0.7, 0.72 + 0.04 * Math.cos(t * 0.27), 0.09, -0.2, -0.5, 0.05 + 0.05 * (1 - b), 0, 0.002, 0.007)];
    },
    // The music from the floor: a column per band, as tall as the band is loud. In silence, nothing.
    media(t, d) {
        const bands = d.spectrum ?? [], out = [];
        if (!d.playing || !bands.length)
            return out;
        const n = Math.min(MAX, bands.length), stride = bands.length / n;
        for (let i = 0; i < n; i++) {
            const level = clamp(Number(bands[Math.floor(i * stride)]) || 0, 0, 1);
            if (level > 0.04)
                out.push(jet((i + 0.5) / n, 0.97, 0.05, 0, -1.6, 0.34 * level, 0.02 * level, 0.09 * level * level, i % 2 ? 0.02 * level : 0));
        }
        return out;
    },
    // Load as furnaces: the busier the machine, the hotter and faster the plumes.
    performance(t, d) {
        const load = clamp(d.cpu ?? 0, 0, 1), gpu = clamp(d.gpu ?? 0, 0, 1), out = [], n = 2 + Math.round(load * 3);
        for (let i = 0; i < n; i++) {
            const wander = 0.03 * Math.sin(t * (0.6 + i * 0.13) + i * 2.1);
            out.push(jet((i + 0.5) / n * 0.72 + wander, 0.98, 0.05, 0, -1.1 - load, 0.08 + 0.34 * load, 0.008, 0.02 + 0.09 * load, 0));
        }
        if (gpu > 0.03)
            out.push(jet(0.88, 0.98, 0.07, 0, -1.4, 0.1 + 0.34 * gpu, 0, 0.02 + 0.09 * gpu, 0.014));
        return out;
    },
    // One slow whirl per desk in use.
    workspaces(t, d) {
        const n = clamp(Math.round(d.desks ?? 1), 1, MAX), out = [];
        for (let i = 0; i < n; i++) {
            const x = (i + 0.5) / n, a = t * 0.8 + i * 1.7;
            out.push(jet(x + 0.05 * Math.cos(a), 0.5 + 0.2 * Math.sin(a), 0.07, -Math.sin(a) * 0.9, Math.cos(a) * 0.9, 0.09, i % 2 ? 0 : 0.006, 0, i % 2 ? 0.006 : 0));
        }
        return out;
    },
    // A signal crossing the room, left to right, sweeping like a scanner.
    devices(t) {
        const y = 0.5 + 0.38 * Math.sin(t * 0.37);
        return [jet(0.02, y, 0.07, 1.5, 0, 0.16, 0.012, 0.012, 0), jet(0.98, 1 - y, 0.07, -1.5, 0, 0.16, 0, 0.012, 0.012)];
    },
    // Each open task is weight: the room's smoke sinks under what's left to do.
    tasks(t, d) {
        const n = clamp(Math.round(d.tasks ?? 0), 0, 6), out = [];
        for (let i = 0; i < n; i++)
            out.push(jet((i + 0.5) / n, 0.04, 0.05, 0.12 * Math.sin(t * 0.4 + i), 0.75, 0.08, 0.008, 0, i % 3 === 0 ? 0.006 : 0));
        return out;
    },
    // A jet going round the room like a hand, faster with a timer running.
    timers(t, d) {
        const a = t * (d.running ? 1.5 : 0.4) - Math.PI / 2;
        return [jet(0.5 + 0.26 * Math.cos(a), 0.5 + 0.38 * Math.sin(a), 0.05, -Math.sin(a) * 1.5, Math.cos(a) * 1.5, 0.2, 0.012, d.running ? 0.04 : 0.008, 0)];
    },
    // Two streams that meet in the middle, as things copied meet things pasted.
    clipboard(t) {
        const s = 0.5 + 0.2 * Math.sin(t * 0.43);
        return [jet(0.04, s, 0.07, 1.1, 0, 0.1, 0.012, 0, 0), jet(0.96, 1 - s, 0.07, -1.1, 0, 0.1, 0, 0, 0.012)];
    },
    // Unread things falling; a count only.
    notifications(t, d) {
        const n = clamp(Math.ceil((d.unread ?? 0) / 6), 0, 6), out = [];
        for (let i = 0; i < n; i++) {
            const y = ((t * (0.08 + i * 0.013) + i * 0.37) % 1);
            out.push(jet(((i * 0.618 + 0.13) % 1) * 0.9 + 0.05, y, 0.03, 0, 0.9, 0.09, 0, 0.01, 0.011));
        }
        return out;
    },
    // Still reading: a single thread of smoke from a candle at the foot of the page.
    codex(t) {
        return [jet(0.5 + 0.015 * Math.sin(t * 0.9), 0.98, 0.022, 0, -0.9, 0.08, 0.01, 0.024, 0)];
    }
};
function emitters(room, t, data) {
    const law = LAWS[room];
    return law ? law(t, data ?? {}).slice(0, MAX) : [];
}
// Where a room lives on the sky, so that going there strikes the gas from that side: the rooms round a circle in their order.
function roomBearing(room, rooms) {
    const i = rooms.indexOf(room);
    if (i < 0)
        return null;
    const a = (i / rooms.length) * Math.PI * 2 - Math.PI / 2;
    return { x: 0.5 + 0.42 * Math.cos(a), y: 0.5 + 0.42 * Math.sin(a), dx: -Math.cos(a), dy: -Math.sin(a) };
}
