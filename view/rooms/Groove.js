.pragma library

// Groove geometry (atlas #12, docs/OVERDRIVE.md §29): the track cuts its own record as you listen. Pure, no Qt and no
// clock; tests run it under Node (tests/test_groove.py). A groove is BUCKETS cells along the track; each keeps the
// loudest energy (0–1) heard there while it played. A cell never played, or heard only while paused, stays 0: a dead
// groove, straight.

const BUCKETS = 160;
const GRAIN = 3;         // px per half-wave: the engraving's grain, sampled every pixel

function empty() {
    const out = [];
    for (let i = 0; i < BUCKETS; i++) out.push(0);
    return out;
}
// The groove after hearing `energy` (0–1) at `position` of a `length`-second track. Paused, nothing is cut.
function record(groove, position, length, energy, playing) {
    const g = Array.isArray(groove) && groove.length === BUCKETS ? groove : empty();
    if (!playing || !(length > 0) || !(position >= 0) || position > length)
        return g;
    const i = Math.min(BUCKETS - 1, Math.floor(position / length * BUCKETS));
    const e = Math.max(0, Math.min(1, energy));
    if (e <= g[i])
        return g;
    const next = g.slice();
    next[i] = e;
    return next;
}
// The engraved line across `width` around the middle of `height`, up to `progress` (0–1): [Qt-free {x, y}] points.
// Each cell wiggles by its energy, inside the seek bar's blades (6 px in from the edges); a dead cell is straight.
function path(groove, width, height, progress) {
    const g = Array.isArray(groove) && groove.length === BUCKETS ? groove : empty();
    const mid = height / 2, amp = Math.max(0, height / 2 - 6), end = Math.max(0, Math.min(1, progress)) * width;
    const out = [{ x: 0, y: mid }];
    const steps = Math.ceil(end);
    for (let s = 1; s <= steps; s++) {
        const x = Math.min(end, s);
        const cell = Math.min(BUCKETS - 1, Math.floor(x / width * BUCKETS));
        out.push({ x: x, y: mid + Math.sin((x + 0.5) * Math.PI / GRAIN) * amp * g[cell] });
    }
    return out;
}
// A track's key in the session's grooves: its title, artist and length, nothing else.
function key(player) {
    return player ? [player.artist || "", player.title || "", Math.round(player.length || 0)].join(" · ") : "";
}
