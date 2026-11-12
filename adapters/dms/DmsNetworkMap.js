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
            secured: n.secured === true, known: n.saved === true, connected: n.connected === true
        });
    }
    return out;
}

function sameNetworks(a, b) {
    return JSON.stringify(a) === JSON.stringify(b);
}

// What connect(id) does: "none" (already on it), "connect" (a saved network) or "unknown" (hand over to settings).
function connectAction(data, id) {
    if (!data || typeof id !== "string" || id === "") return "none";
    if (data.wifiConnected === true && data.wifiSSID === id) return "none";
    const saved = (data.savedWifiNetworks ?? []).some(n => n && n.ssid === id);
    const listed = (data.wifiNetworks ?? []).some(n => n && n.ssid === id && n.saved === true);
    if (saved || listed) return "connect";
    return "unknown";
}
