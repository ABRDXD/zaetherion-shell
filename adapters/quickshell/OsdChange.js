.pragma library

// When a level change is an OSD event (docs/SURFACES.md "OSD", Z24). Pure; behaviour after DMS v2.1.0's
// VolumeOSD and SessionData.suppressOSD (Z161): nothing shows while quiet (the first 2 s after start, after a
// resume), a change of default device is a new baseline, not a change, and a level that moves by less than
// half a percent (Pipewire's rounding) is not a change.

const STEP = 0.005;

// state: { [kind]: { node, level, muted } }. sample: { kind, node, level, muted }.
// Returns { state, event } where event is { kind, level, muted } or null.
function next(state, sample, quiet) {
    const was = state ? state[sample.kind] : undefined;
    const kept = Object.assign({}, state || {});
    kept[sample.kind] = { node: sample.node, level: sample.level, muted: sample.muted };
    const changed = was !== undefined && was.node === sample.node
        && (Math.abs(was.level - sample.level) >= STEP || was.muted !== sample.muted);
    return {
        state: kept,
        event: changed && !quiet ? { kind: sample.kind, level: Math.max(0, sample.level), muted: !!sample.muted } : null
    };
}
