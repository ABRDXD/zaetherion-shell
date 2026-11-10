.pragma library
// The graphics card's chart recorder (docs/OVERDRIVE.md §45; Claude B's own idea): Performance's record with GPU
// chosen. Pure: no Qt, so Node tests run it (tests/test_recorder.py). A reading is core/telemetry.py's `telemetry.gpu`.
//
// A circular chart that turns once a minute under a fixed stylus, as a chart recorder's paper does: the outer trace is
// the card's busy share (the centre is idle, the rim flat out), the inner, stepped trace is the clock level it has
// engaged (its DPM ladder), and the chart keeps exactly one revolution, the stylus writing over the minute before.
// VRAM in use is an arc on the rim; a card that sleeps is named asleep, and never asked anything else.

const REV = 60;    // s a revolution

// The integrated card (AMD, awake) and the others: {main, others}.
function cards(reading) {
    const gpus = reading?.gpus ?? [];
    const main = gpus.find(g => g.busy !== undefined) ?? null;
    return { main: main, others: gpus.filter(g => g !== main) };
}
// The chart after a sample at t (s): [{t, busy, level}], one revolution kept.
function record(trace, t, main) {
    if (!main)
        return trace.filter(e => t - e.t < REV);
    const levels = Math.max(1, (main.levels?.length ?? 1) - 1);
    return trace.filter(e => t - e.t < REV).concat([{ t: t, busy: Math.max(0, Math.min(1, main.busy)), level: (main.level ?? 0) / levels }]);
}
// A sample's angle on the chart (radians, 0 at the top, clockwise), seen at time `now`: the chart turns so that `now` is
// under the stylus at the top.
function angle(t, now) {
    return -2 * Math.PI * (now - t) / REV;
}
// The traces' radii (shares of the chart's radius): the busy trace between 0.42 and 0.96, the level trace between 0.16
// and 0.36.
function busyR(b) { return 0.42 + 0.54 * Math.max(0, Math.min(1, b)); }
function levelR(l) { return 0.16 + 0.2 * Math.max(0, Math.min(1, l)); }
// The caption: "AMD 1100 MHZ · 37% · VRAM 100/400 MB · NVIDIA ASLEEP".
function caption(reading) {
    const c = cards(reading), parts = [];
    if (c.main) {
        const mhz = c.main.levels?.[c.main.level] ?? 0;
        parts.push(c.main.vendor + " " + mhz + " MHZ · " + Math.round(100 * c.main.busy) + "% · VRAM "
                   + Math.round((c.main.vram ?? 0) / 1048576) + "/" + Math.round((c.main.total ?? 0) / 1048576) + " MB");
    }
    for (const g of c.others)
        parts.push(g.vendor + (g.awake ? " AWAKE" : " ASLEEP"));
    return parts.join(" · ");
}
