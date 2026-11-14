.pragma library

// DMS `bluetooth` snapshot → the contract's BluetoothDomain values (docs/NET_BT.md §1, §2). Pure.
// A DMS device: {path, address, name, alias, paired, trusted, blocked, connected, class, icon, rssi, legacyPairing}
// (field names read from the dms 2.1.0 binary; no battery). Battery comes from the caller (Quickshell's module).
//
// kindOf() and hasRealName() are adapted from DMS's Services/BluetoothService.qml (getDeviceIcon, hasRealName),
// MIT, "Copyright (c) 2025 Avenge Media LLC" (licenses/DUX-SHELL-MIT, NOTICE).

// Bluetooth class of device, major class "audio/video" (bits 8–12 = 4) and "peripheral" (5).
const MAJOR_AUDIO = 4;

function enabled(data) {
    return !!data && data.powered === true;
}

function discovering(data) {
    return !!data && data.discovering === true;
}

// The adapter DMS reports first, or "" (DMS then uses its default).
function adapterPath(data) {
    const a = Array.isArray(data?.adapters) ? data.adapters[0] : null;
    return a && typeof a.path === "string" ? a.path : "";
}

function nameOf(d) {
    return String(d.alias || d.name || d.address || "");
}

function hasRealName(d) {
    const name = String(d.alias || d.name || "");
    return name !== "" && name !== String(d.address || "").replace(/:/g, "-") && name !== String(d.address || "");
}

// Our glyph names (Material Symbols), from BlueZ's icon name and the device name, as DMS decides.
function kindOf(d) {
    const name = nameOf(d).toLowerCase();
    const icon = String(d.icon || "").toLowerCase();
    const has = words => words.some(w => icon.indexOf(w) >= 0 || name.indexOf(w) >= 0);
    // Speakers before the generic "audio" words: BlueZ names a speaker's icon "audio-card" (DMS reads it as a headset).
    if (has(["speaker", "soundbar", "audio-card"])) return "speaker";
    if (has(["headset", "audio", "headphone", "airpod", "arctis", "earbud", "buds"])) return "headphones";
    if (has(["mouse"])) return "mouse";
    if (has(["keyboard"])) return "keyboard";
    if (has(["gaming", "gamepad", "controller", "joystick"])) return "sports_esports";
    if (has(["phone", "iphone", "android", "samsung"])) return "smartphone";
    if (has(["watch"])) return "watch";
    if (has(["display", "tv"])) return "tv";
    if (has(["computer", "laptop"])) return "computer";
    return "bluetooth";
}

function isAudio(d) {
    const major = ((Number(d.class) || 0) >> 8) & 0x1f;
    const kind = kindOf(d);
    return major === MAJOR_AUDIO || kind === "headphones" || kind === "speaker";
}

function all(data) {
    return Array.isArray(data?.devices) ? data.devices.filter(d => d && typeof d.address === "string" && d.address !== "") : [];
}

function row(d, batteryOf) {
    const b = batteryOf ? Number(batteryOf(d.address)) : -1;
    return {
        id: d.address, name: nameOf(d), kind: kindOf(d), audio: isAudio(d),
        connected: d.connected === true, paired: d.paired === true, trusted: d.trusted === true,
        blocked: d.blocked === true, battery: Number.isFinite(b) && b >= 0 ? Math.min(1, b) : -1
    };
}

// Paired or connected devices: connected first, then audio, then by name (the owner's "audio devices first").
function devices(data, batteryOf) {
    const seen = {};
    const out = [];
    for (const d of all(data)) {
        if (seen[d.address] || !(d.paired === true || d.connected === true)) continue;
        seen[d.address] = true;
        out.push(row(d, batteryOf));
    }
    return out.sort((a, b) => (b.connected - a.connected) || (b.audio - a.audio) || a.name.localeCompare(b.name));
}

// Unpaired devices nearby, only while the `scan` lease is held: real names only, strongest first.
function nearby(data, held) {
    if (!held) return [];
    const seen = {};
    const out = [];
    for (const d of all(data)) {
        if (seen[d.address] || d.paired === true || d.connected === true || !hasRealName(d)) continue;
        seen[d.address] = true;
        out.push(Object.assign(row(d, null), { strength: strength(d.rssi) }));
    }
    return out.sort((a, b) => (b.audio - a.audio) || (b.strength - a.strength) || a.name.localeCompare(b.name));
}

// RSSI (dBm) → 0..1: -100 or less is 0, -40 or more is 1.
function strength(rssi) {
    const r = Number(rssi);
    if (!Number.isFinite(r) || r === 0) return 0;
    return Math.max(0, Math.min(1, (r + 100) / 60));
}

function pathOf(data, id) {
    const d = all(data).find(x => x.address === id);
    return d && typeof d.path === "string" ? d.path : "";
}

// What a snapshot says about an attempt (DmsAttempt.observe). DMS reports no "connecting" state, so progress is
// never seen: the outcome is the snapshot, the reply's error, or the deadline.
function observation(data, attempt) {
    if (!data || !attempt) return null;
    const d = all(data).find(x => x.address === attempt.target) ?? null;
    let ok = false;
    switch (attempt.action) {
    case "connect": ok = !!d && d.connected === true; break;
    case "disconnect": ok = !d || d.connected !== true; break;
    case "pair": ok = !!d && d.paired === true; break;
    case "forget": ok = !d || d.paired !== true; break;
    case "trust:on": ok = !!d && d.trusted === true; break;
    case "trust:off": ok = !!d && d.trusted !== true; break;
    default: return null;
    }
    return { ok: ok, progress: false, reason: "", wrongSecret: false };
}

function same(a, b) {
    return JSON.stringify(a) === JSON.stringify(b);
}
