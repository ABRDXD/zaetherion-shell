.pragma library
// The disk as a tide (docs/OVERDRIVE.md §44; Claude B's own idea): Performance's record with DISK chosen. Pure: no Qt,
// so Node tests run it (tests/test_tide.py). A reading is core/telemetry.py's `telemetry.disk`: {read, written, busy}.
//
// The water's level is how busy the disks are (the share of time spent doing I/O), eased like water; reads run the
// tide in (its waves travel left, towards the record's start), writes draw it out (rightwards), each as fast as the
// logarithm of its bytes a second. A burst leaves a wrack line at its high-water mark that stays for five minutes,
// fading; the session's highest water stays as the tideline, with its time.

const WRACK_LIFE = 300;    // s
const WRACK_MIN = 0.12;    // a peak at least this high leaves a wrack line
const WRACKS = 8;

function clamp01(v) { return Math.max(0, Math.min(1, v)); }

// The level after dt s, eased towards the busy share (rising faster than it falls, as a tide comes in fast here).
function level(current, busy, dt) {
    const target = clamp01(busy);
    const tau = target > current ? 1.2 : 4;
    return current + (target - current) * (1 - Math.exp(-Math.max(0, dt) / tau));
}

// The waves' speed (px a second, signed: negative runs left) from the bytes read and written a second.
function drift(read, written) {
    const pull = b => Math.log10(1 + Math.max(0, b) / 4096);
    return Math.round((pull(written) - pull(read)) * 12 * 10) / 10;
}

// The state after a sample: {level, rising, wracks: [{h, at}], high: {h, at}}. A peak is the level turning down after
// rising; one high enough leaves a wrack line.
function step(state, busy, dt, t) {
    const s = state ?? { level: 0, rising: false, wracks: [], high: { h: 0, at: 0 } };
    const next = level(s.level, busy, dt);
    let wracks = s.wracks.filter(w => t - w.at <= WRACK_LIFE);
    if (s.rising && next < s.level && s.level >= WRACK_MIN)
        wracks = wracks.concat([{ h: s.level, at: t }]).slice(-WRACKS);
    const high = next > s.high.h ? { h: next, at: t } : s.high;
    return { level: next, rising: next > s.level, wracks: wracks, high: high };
}
// A wrack line's strength (1 fresh, 0 gone).
function fade(w, t) {
    return clamp01(1 - (t - w.at) / WRACK_LIFE);
}
