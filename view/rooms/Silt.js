.pragma library
// The swap as silt (docs/OVERDRIVE.md §46; Claude B's own idea): Performance's record with SWAP chosen. Pure: no Qt, so
// Node tests run it (tests/test_silt.py). A reading is core/telemetry.py's `telemetry.swap`: {in, out, used, total}.
//
// Pages swapped out fall through the record as grains and settle on a bed as deep as the swap in use; pages swapped back
// in lift grains off the bed and carry them up out of the record. The bed is laid down in bands, one a minute, each
// darker as it ages under the ones above (compaction), so a session's paging stands as strata.

const BAND = 60;        // s a band takes to lay down
const BANDS = 12;
const FALL = 1.1;       // s a grain takes to fall or rise

function clamp01(v) { return Math.max(0, Math.min(1, v)); }

// Grains a second for a page rate: none for none, about one per doubling, at most 10.
function grains(pages) {
    return pages > 0 ? Math.min(10, Math.ceil(Math.log2(1 + pages / 16))) : 0;
}
// The bed's depth (0–0.8 of the record) for the swap in use.
function depth(used, total) {
    return total > 0 ? 0.8 * clamp01(used / total) : 0;
}
// The bands after a sample at t: [{from, h}] (h: the bed's depth when the band was laid), one a minute, newest last.
function lay(bands, t, d) {
    const last = bands.length ? bands[bands.length - 1] : null;
    if (last && t - last.from < BAND)
        return bands.slice(0, -1).concat([{ from: last.from, h: Math.max(last.h, d) }]);
    return bands.concat([{ from: t, h: d }]).slice(-BANDS);
}
// A band's darkness: the newest is light, older ones compacted darker.
function compaction(index, count) {
    return count > 1 ? 0.08 + 0.3 * (1 - index / (count - 1)) : 0.08;
}
// A grain's place at time t: {x, y (0 top, 1 bottom), alive}. A falling grain drops from the top to the bed's surface; a
// rising one goes from the surface up out of the top.
function place(g, t, bed) {
    const k = clamp01((t - g.born) / FALL), surface = 1 - bed;
    const y = g.up ? surface - (surface + 0.05) * k * k : surface * (k * k);
    return { x: g.x, y: y, alive: k < 1 };
}
