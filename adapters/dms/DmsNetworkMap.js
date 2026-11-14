.pragma library

// DMS `network` snapshot → the contract's NetworkDomain values (docs/DMS_ADAPTER.md §4). Pure.

// "ethernet", "wifi" or "none". Decided from the boolean flags: a scrubbed or odd snapshot can hold text in
// fields that were empty, so an empty string means nothing here.
function kind(data) {
    if (!data) return "none";
    const wired = data.ethernetConnected === true;
    const wireless = data.wifiConnected === true;
    if (data.networkStatus === "ethernet" && wired) return "ethernet";
    if (data.networkStatus === "wifi" && wireless) return "wifi";
    if (wired) return "ethernet";
    if (wireless) return "wifi";
    return "none";
}

function wifiEnabled(data) {
    return !!data && data.wifiEnabled === true;
}

function name(data) {
    const k = kind(data);
    if (k === "wifi") return String(data.wifiSSID ?? "");
    if (k === "ethernet") return String(data.ethernetDevice ?? "");
    return "";
}

// Only while the `details` lease is held; the address is already in the snapshot, so no extra call.
function ipAddress(data, details) {
    if (!details) return "";
    const k = kind(data);
    if (k === "wifi") return String(data.wifiIP ?? "");
    if (k === "ethernet") return String(data.ethernetIP ?? "");
    return "";
}

// Only while the `scan` lease is held. Skips empty names, networks out of range and repeated names.
function networks(data, scan) {
    if (!scan || !data || !Array.isArray(data.wifiNetworks)) return [];
    const seen = {};
    const out = [];
    for (const n of data.wifiNetworks) {
        if (!n || typeof n.ssid !== "string" || n.ssid === "" || n.outOfRange === true || seen[n.ssid]) continue;
        seen[n.ssid] = true;
        out.push({
            id: n.ssid, ssid: n.ssid,
            strength: Math.max(0, Math.min(1, (Number(n.signal) || 0) / 100)),
            secured: n.secured === true, known: n.saved === true, connected: n.connected === true,
            enterprise: n.enterprise === true, hidden: n.hidden === true, autoconnect: n.autoconnect === true,
            band: band(n.frequency)
        });
    }
    return out;
}

function sameNetworks(a, b) {
    return JSON.stringify(a) === JSON.stringify(b);
}

// What connect(id) does: "none" (already on it), "connect" (a saved network), "enterprise" (802.1X, not supported in
// FART, docs/NET_BT.md §4) or "unknown" (it needs a password: settings, Z95).
function connectAction(data, id) {
    if (!data || typeof id !== "string" || id === "") return "none";
    if (data.wifiConnected === true && data.wifiSSID === id) return "none";
    if (isSaved(data, id)) return "connect";
    if ((data.wifiNetworks ?? []).some(n => n && n.ssid === id && n.enterprise === true)) return "enterprise";
    return "unknown";
}

function isSaved(data, id) {
    return (data.savedWifiNetworks ?? []).some(n => n && n.ssid === id)
        || (data.wifiNetworks ?? []).some(n => n && n.ssid === id && n.saved === true);
}

// MHz → "2.4", "5", "6" or "" (unknown).
function band(frequency) {
    const f = Number(frequency) || 0;
    if (f <= 0) return "";
    if (f < 3000) return "2.4";
    if (f < 5925) return "5";
    return "6";
}

// Saved networks, for the settings list. Only while the `saved` lease is held.
function saved(data, held) {
    if (!held || !data || !Array.isArray(data.savedWifiNetworks)) return [];
    const near = {};
    for (const n of data.wifiNetworks ?? [])
        if (n && typeof n.ssid === "string" && n.outOfRange !== true) near[n.ssid] = true;
    const seen = {};
    const out = [];
    for (const n of data.savedWifiNetworks) {
        if (!n || typeof n.ssid !== "string" || n.ssid === "" || seen[n.ssid]) continue;
        seen[n.ssid] = true;
        out.push({ id: n.ssid, ssid: n.ssid, autoconnect: n.autoconnect === true, inRange: near[n.ssid] === true,
                   enterprise: n.enterprise === true, connected: data.wifiConnected === true && data.wifiSSID === n.ssid });
    }
    return out;
}

function wired(data) {
    const on = !!data && data.ethernetConnected === true;
    return { connected: on, name: on ? String(data.ethernetDevice ?? "") : "" };
}

// The network being joined right now, as NetworkManager reports it, or "".
function connecting(data) {
    return !!data && data.isConnecting === true ? String(data.connectingSSID ?? "") : "";
}

// VPN profiles with their state. `state` is "on", "starting" or "off"; NetworkManager's in-between states all read
// "starting", only "activated" reads "on".
function vpnState(entry) {
    if (!entry) return "off";
    const s = String(entry.state ?? "activated");
    return s === "activated" || s === "" ? "on" : "starting";
}

function vpn(data) {
    const profiles = Array.isArray(data?.vpnProfiles) ? data.vpnProfiles : [];
    const active = Array.isArray(data?.vpnActive) ? data.vpnActive : [];
    const out = [];
    const seen = {};
    for (const p of profiles) {
        if (!p || typeof p.uuid !== "string" || p.uuid === "" || seen[p.uuid]) continue;
        seen[p.uuid] = true;
        out.push({ id: p.uuid, name: String(p.name ?? p.uuid), state: vpnState(active.find(a => a && a.uuid === p.uuid)) });
    }
    return out;
}

// What a snapshot says about a Wi-Fi attempt (DmsAttempt.observe). Actions: "connect", "join", "disconnect",
// "forget", "autoconnect:on", "autoconnect:off". Joined means connected *with an address*.
function wifiObservation(data, attempt) {
    if (!data || !attempt) return null;
    const id = attempt.target;
    const on = data.wifiConnected === true && data.wifiSSID === id;
    switch (attempt.action) {
    case "connect":
    case "join":
        return { ok: on && String(data.wifiIP ?? "") !== "", progress: connecting(data) === id,
                 reason: String(data.lastError ?? ""), wrongSecret: false };
    case "disconnect":
        return { ok: !on, progress: false, reason: "", wrongSecret: false };
    case "forget":
        return { ok: !isSaved(data, id), progress: false, reason: "", wrongSecret: false };
    case "autoconnect:on":
    case "autoconnect:off": {
        const want = attempt.action === "autoconnect:on";
        const entry = (data.savedWifiNetworks ?? []).find(n => n && n.ssid === id);
        return { ok: !!entry && (entry.autoconnect === true) === want, progress: false, reason: "", wrongSecret: false };
    }
    }
    return null;
}

// Actions "vpn:on", "vpn:off"; the target is the profile's uuid.
function vpnObservation(data, attempt) {
    if (!data || !attempt) return null;
    const entry = vpn(data).find(p => p.id === attempt.target);
    const state = entry ? entry.state : "off";
    const reason = data.vpnErrorUuid === attempt.target ? String(data.vpnError ?? "") : "";
    if (attempt.action === "vpn:on")
        return { ok: state === "on", progress: state === "starting", reason: reason, wrongSecret: false };
    return { ok: state === "off", progress: state === "starting", reason: reason, wrongSecret: false };
}
