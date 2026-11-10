.pragma library
// The process spectrograph (docs/OVERDRIVE.md §40; atlas #74). Pure: no Qt, so Node tests run it
// (tests/test_spectro.py). Its samples are the orrery's (core/orrery.py): bodies {id, name, cpu, rss, age, born}.
//
// Performance's record, with MEM chosen: the processes as spectral lines, read like an instrument's plate rather than a
// task manager. Each process is a vertical line at its lifetime class (x: the logarithm of its age, from a second at the
// left to a week at the right), as tall as its CPU share (a log scale, so a busy core and an idle daemon both show), as
// thick as its memory. Each time a process's CPU stops and starts again it is interrupted, and each interruption in
// the last minute is a notch cut out of its line. So long-lived daemons stand as thin, short, notched lines at the
// right, and a build's explosive children as tall bright strokes at the far left. Forks between samples spark at the
// left edge; a process that ends leaves its line's ghost for five seconds.

const AGE_MIN = 1, AGE_MAX = 7 * 86400;   // s, the x axis
const CPU_MAX = 400;                       // % of a core, the top of the y axis
const NOTCH_WINDOW = 60;                   // s of interruptions kept
const GHOST = 5;                           // s an ended line stays

function clamp01(v) { return Math.max(0, Math.min(1, v)); }

// x (0–1) of an age in seconds.
function ageX(age) {
    const a = Math.max(AGE_MIN, Math.min(AGE_MAX, age ?? AGE_MIN));
    return Math.log(a / AGE_MIN) / Math.log(AGE_MAX / AGE_MIN);
}
// Height (0–1) of a CPU share (% of one core): a log scale from 0.1 %, so idle is 0 and four cores is 1.
function cpuY(cpu) {
    if (!(cpu > 0.1)) return 0;
    return clamp01(Math.log(cpu / 0.1) / Math.log(CPU_MAX / 0.1));
}
// Thickness in px of a resident size in MiB: 1 px under 16 MiB, up to 7 px at 4 GiB.
function thick(rss) {
    return Math.round((1 + 6 * clamp01(Math.log2(Math.max(16, rss ?? 0) / 16) / 8)) * 10) / 10;
}
// The lifetime class's name, for the axis's marks.
const MARKS = [[1, "1 S"], [60, "1 MIN"], [3600, "1 H"], [86400, "1 D"], [7 * 86400, "1 WK"]];

// Each process's track: {id: {name, active, notches: [t], last, x, y, w, gone}}. `bodies` is one sample at time t (s).
// An interruption is a process that was using the CPU, then didn't, then did again: one notch, at the restart.
function track(tracks, bodies, t) {
    const out = {}, seen = {};
    for (const b of bodies ?? []) {
        seen[b.id] = true;
        const before = tracks[b.id];
        const busy = (b.cpu ?? 0) > 0.1;
        let notches = before ? before.notches.filter(n => t - n <= NOTCH_WINDOW) : [];
        if (before && busy && before.paused)
            notches = notches.concat([t]);
        // Paused: it has used the CPU and now doesn't.
        const paused = before ? (busy ? false : (before.wasBusy || before.paused)) : false;
        out[b.id] = { name: b.name, x: ageX(b.age), y: cpuY(b.cpu), w: thick(b.rss), notches: notches, paused: paused, wasBusy: busy,
                      born: !!b.born, gone: 0, last: t };
    }
    for (const id in tracks) {
        if (seen[id])
            continue;
        const g = tracks[id];
        const gone = g.gone || t;
        if (t - gone <= GHOST)
            out[id] = Object.assign({}, g, { gone: gone });
    }
    return out;
}
// The tallest few live lines, to be named.
function named(tracks, count) {
    return Object.keys(tracks).filter(id => !tracks[id].gone && tracks[id].y > 0)
        .sort((a, b) => tracks[b].y - tracks[a].y).slice(0, count);
}
// The notches' places along a line of height h px: evenly spaced in its upper four fifths, newest at the top.
function notchYs(n, h) {
    const out = [];
    for (let i = 0; i < n; i++)
        out.push(h * (0.2 + 0.8 * (i + 1) / (n + 1)));
    return out;
}
