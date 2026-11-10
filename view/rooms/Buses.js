.pragma library
// Devices' bus schematic (docs/OVERDRIVE.md §38; atlas #21 Bus Topology). Pure: no Qt, so Node tests run it
// (tests/test_buses.py). A reading is core/buses.py's: controllers with their root hubs, and devices by port path.
//
// The machine's USB as it is wired: one column per controller (a PCI device), its root hubs as rails (the USB 2 rail a
// hairline, the USB 3 rail heavy), each port a tap off its rail: open where nothing is plugged, ending in the device
// (its kind, speed and product) where something is, and a hub's own ports indented under it. The session remembers what
// each port has held: a port that held a device keeps its ghost (kind, faint, "OUT 14:02"), and a device plugged in in
// the last 12 s is inked fresh. The Bluetooth devices linked now hang off the radio's port as an island (wireless taps),
// and the audio endpoints (outputs and inputs, the default marked, the streams playing counted) are a column of their
// own: the room's own lists, not read again.

const FRESH = 12000;     // ms a new device is inked fresh
// The session's port memory (not saved; a restart forgets it).
const kept = { memory: {} };

function speedTag(mbps) {
    if (!(mbps > 0)) return "";
    return mbps >= 1000 ? Math.round(mbps / 1000) + "G" : Math.round(mbps) + "M";
}
// A line weight for a speed: full speed and below a hairline, high speed 1.5, SuperSpeed 2.5.
function weight(mbps) {
    return mbps >= 5000 ? 2.5 : mbps >= 480 ? 1.5 : 1;
}

// The path of port `p` on a hub: a root hub `usbN`'s ports are `N-p`; a device hub `1-3`'s are `1-3.p`.
function portPath(hub, p) {
    return hub.startsWith("usb") ? hub.slice(3) + "-" + p : hub + "." + p;
}

// The rows of one controller's column: [{rail, depth, path, port, device, speed}], each root hub's ports in order and a
// hub's ports right under it (depth + 1). `rail` is the root hub's index in the controller (0: USB 2, 1: USB 3).
function rows(controller, devices) {
    const byPath = {};
    for (const d of devices ?? [])
        byPath[d.path] = d;
    const out = [];
    const walk = (hub, ports, rail, depth, speed) => {
        for (let p = 1; p <= ports; p++) {
            const path = portPath(hub, p), device = byPath[path] ?? null;
            out.push({ rail: rail, depth: depth, path: path, port: p, device: device, speed: device ? device.speed : speed });
            if (device && device.ports > 0 && depth < 4)
                walk(device.path, device.ports, rail, depth + 1, device.speed);
        }
    };
    (controller.hubs ?? []).forEach((h, rail) => walk("usb" + h.bus, h.ports, rail, 0, h.speed));
    return out;
}

// The columns: [{pci, rails: [speed], rows}] for every controller.
function columns(reading) {
    if (!reading || !reading.controllers)
        return [];
    return reading.controllers.map(c => ({ pci: c.pci, rails: c.hubs.map(h => h.speed), rows: rows(c, reading.devices) }));
}

// The session's memory of each port: {path: {kind, product, speed, first, last, out}}: when a device was first and last
// seen there, and when it left (`out`, 0 while it is plugged in).
function remember(memory, devices, now) {
    const next = {};
    for (const k in memory)
        next[k] = Object.assign({}, memory[k]);
    const present = {};
    for (const d of devices ?? []) {
        present[d.path] = true;
        const m = next[d.path];
        const same = m && m.kind === d.kind && m.product === d.product && m.out === 0;
        next[d.path] = { kind: d.kind, product: d.product, speed: d.speed, first: same ? m.first : now, last: now, out: 0 };
    }
    for (const k in next)
        if (!present[k] && next[k].out === 0)
            next[k].out = now;
    return next;
}
// What a row shows: "device" (plugged in), "fresh" (plugged in in the last FRESH ms, and not since the first look),
// "ghost" (something was here this session), or "open".
function state(row, memory, now, since) {
    const m = memory[row.path];
    if (row.device)
        return m && m.first > since && now - m.first < FRESH ? "fresh" : "device";
    return m && m.out > 0 ? "ghost" : "open";
}
function clock(ms) {
    const d = new Date(ms);
    return String(d.getHours()).padStart(2, "0") + ":" + String(d.getMinutes()).padStart(2, "0");
}

// The Bluetooth island: after the radio's row, one row per device linked now or earlier this session (path "bt:<id>"),
// wireless, a level deeper; one that has dropped shows its ghost.
function island(rows, bluetooth, memory) {
    const linked = (bluetooth ?? []).filter(d => d.connected || (memory ?? {})["bt:" + d.id]);
    const at = rows.findIndex(r => r.device && r.device.kind === "RADIO");
    if (at < 0 || !linked.length)
        return rows;
    const extra = linked.map(d => ({ rail: rows[at].rail, depth: rows[at].depth + 1, path: "bt:" + d.id, port: 0, wireless: true,
                                     device: d.connected ? { path: "bt:" + d.id, kind: "BT", speed: 0, product: d.name ?? "", ports: 0 } : null, speed: 0 }));
    return rows.slice(0, at + 1).concat(extra, rows.slice(at + 1));
}
// The audio column: outputs then inputs, each an endpoint row (path "audio:<id>"); the default output carries the count of
// streams playing.
function audio(outputs, inputs, streams) {
    const row = (d, kind) => ({ rail: 0, depth: 0, path: "audio:" + d.id, port: 0,
                                device: { path: "audio:" + d.id, kind: kind + (d.isDefault ? " ●" : ""), speed: 0,
                                          product: (d.name ?? "") + (d.isDefault && kind === "OUT" && (streams ?? []).length ? " · " + streams.length + " PLAYING" : ""), ports: 0 }, speed: 0 });
    const rows = (outputs ?? []).map(d => row(d, "OUT")).concat((inputs ?? []).map(d => row(d, "IN")));
    return rows.length ? { pci: "AUDIO", rails: [0], rows: rows } : null;
}
// Everything the schematic shows: the USB columns with the island in place, then the audio column.
function all(reading, bluetooth, outputs, inputs, streams, memory) {
    const cols = columns(reading).map(c => ({ pci: c.pci, rails: c.rails, rows: island(c.rows, bluetooth, memory) }));
    const a = audio(outputs, inputs, streams);
    return a ? cols.concat([a]) : cols;
}
// The devices the memory keeps: USB, the linked Bluetooth ones and the endpoints.
function present(reading, bluetooth, outputs, inputs) {
    return (reading?.devices ?? []).concat((bluetooth ?? []).filter(d => d.connected).map(d => ({ path: "bt:" + d.id, kind: "BT", product: d.name ?? "", speed: 0 })),
                                           (outputs ?? []).concat(inputs ?? []).map(d => ({ path: "audio:" + d.id, kind: "AUDIO", product: d.name ?? "", speed: 0 })));
}
