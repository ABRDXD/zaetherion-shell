.pragma library

// Phantom ports (atlas #23, docs/OVERDRIVE.md §25): pure, no Qt and no clock, so tests run it under Node
// (tests/test_ports.py). Sightings are kept for the view's session only (ViewState.deviceSightings, never saved):
// {id: {name, connected, lost}}. A device that was linked when last seen and isn't now (disconnected, or gone from the
// list) is a phantom from the moment that was noticed until it links again or the session ends.

// The sightings after looking at `devices` ([{id, name, connected}]) at time `now`.
function sight(sightings, devices, now) {
    const next = Object.assign({}, sightings || {});
    const present = {};
    for (const d of devices || []) {
        present[d.id] = true;
        const before = next[d.id];
        if (d.connected)
            next[d.id] = { name: d.name, connected: true, lost: 0 };
        else if (before && before.connected)
            next[d.id] = { name: d.name, connected: false, lost: now };
        else if (!before)
            next[d.id] = { name: d.name, connected: false, lost: 0 };
        else
            next[d.id] = Object.assign({}, before, { name: d.name });
    }
    for (const id of Object.keys(next))
        if (!present[id] && next[id].connected)
            next[id] = { name: next[id].name, connected: false, lost: now, gone: true };
        else if (!present[id] && next[id].lost > 0)
            next[id] = Object.assign({}, next[id], { gone: true });
    return next;
}

// The phantoms: {id: lost} for devices still listed, and the gone ones as rows of their own.
function phantoms(sightings) {
    const left = {}, gone = [];
    for (const id of Object.keys(sightings || {})) {
        const s = sightings[id];
        if (!(s.lost > 0)) continue;
        if (s.gone) gone.push({ id: id, name: s.name, lost: s.lost, phantom: true, connected: false });
        else left[id] = s.lost;
    }
    gone.sort((a, b) => b.lost - a.lost);
    return { left: left, gone: gone };
}
