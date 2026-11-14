.pragma library

// What the Wi-Fi, VPN and Bluetooth settings say about an attempt or a prompt (docs/NET_BT.md §3 point 5). Pure.
// An attempt is the contract's { target, action, phase, reason }; `name` is what the person knows it by (the
// network's name, the VPN's or the device's). Returns { line, detail, busy, retry, ok } or null; ok: it worked.

const VERBS = {
    join: ["Joining", "Joined", "join"], connect: ["Joining", "Joined", "join"], disconnect: ["Leaving", "Left", "leave"],
    forget: ["Forgetting", "Forgot", "forget"], "autoconnect:on": ["Turning on auto-join for", "Auto-join is on for", "change auto-join for"],
    "autoconnect:off": ["Turning off auto-join for", "Auto-join is off for", "change auto-join for"],
    "vpn:on": ["Starting", "Started", "start"], "vpn:off": ["Stopping", "Stopped", "stop"],
    "bt:connect": ["Connecting", "Connected", "connect"], "bt:disconnect": ["Disconnecting", "Disconnected", "disconnect"],
    "bt:pair": ["Pairing with", "Paired with", "pair with"], "bt:forget": ["Forgetting", "Forgot", "forget"],
    "bt:trust:on": ["Trusting", "Trusted", "trust"], "bt:trust:off": ["Untrusting", "No longer trusting", "untrust"]
};

// `kind` is "wifi", "vpn" or "bt" (Bluetooth actions share some names with Wi-Fi's).
function attempt(a, name, kind) {
    if (!a) return null;
    const key = kind === "bt" ? "bt:" + a.action : a.action;
    const verb = VERBS[key] ?? ["Working on", "Done with", "finish"];
    const who = name || a.target || "it";
    const reason = a.reason || "";
    switch (a.phase) {
    case "working":
        return { line: verb[0] + " " + who + "…", detail: "", busy: true, retry: false, ok: false };
    case "lost":
        return { line: "DMS restarted. Checking " + who + "…", detail: "", busy: true, retry: false, ok: false };
    case "done":
        return { line: verb[1] + " " + who + ".", detail: "", busy: false, retry: false, ok: true };
    case "wrong-secret":
        return { line: kind === "bt" ? "Wrong code for " + who + "." : "Wrong password for " + who + ". Type it again.",
                 detail: "", busy: true, retry: false, ok: false };
    case "timeout":
        return { line: reason === "no-answer" ? "DMS didn't answer. Couldn't " + verb[2] + " " + who + "."
                                              : "Timed out. Couldn't " + verb[2] + " " + who + ".",
                 detail: "", busy: false, retry: true, ok: false };
    case "cancelled":
        return { line: reason === "prompt-timeout" ? "Nothing was typed in 90 s, so " + who + " was cancelled."
                                                   : "Cancelled.",
                 detail: "", busy: false, retry: reason === "prompt-timeout", ok: false };
    case "failed":
        if (reason === "enterprise")
            return { line: who + " needs a username or certificate (enterprise Wi-Fi). FART can't join those yet.",
                     detail: "", busy: false, retry: false, ok: false };
        if (reason === "dms-restarted")
            return { line: "DMS restarted. Couldn't " + verb[2] + " " + who + ".", detail: "", busy: false, retry: true, ok: false };
        if (reason === "offline")
            return { line: "DMS is offline. Couldn't " + verb[2] + " " + who + ".", detail: "", busy: false, retry: true, ok: false };
        return { line: "Couldn't " + verb[2] + " " + who + ".", detail: reason, busy: false, retry: true, ok: false };
    }
    return null;
}

// The password prompt's heading.
function prompt(p) {
    if (!p) return "";
    const who = p.name || p.ssid || "This network";
    if (p.kind === "unsupported") return who + " asks for more than a password. FART can't answer that yet.";
    if (p.reason === "wrong-password") return "Wrong password for " + who + ". Type it again.";
    return who + " needs its " + (p.kind === "vpn" ? "VPN password" : "password") + ".";
}

// Bluetooth's pairing request, in words, and what the person can answer.
function pairing(p) {
    if (!p) return null;
    const who = p.deviceName || "The device";
    switch (p.kind) {
    case "confirm": return { line: "Does " + who + " show " + p.passkey + "?", field: "", yes: "Yes, pair", no: "No" };
    case "display-passkey": return { line: "Type " + p.passkey + " on " + who + ".", field: "", yes: "", no: "Cancel" };
    case "authorize": return { line: "Allow " + who + " to connect?", field: "", yes: "Allow", no: "Deny" };
    case "pin": return { line: who + " asks for a PIN.", field: "PIN", yes: "Pair", no: "Cancel" };
    case "passkey": return { line: who + " asks for its 6-digit passkey.", field: "Passkey", yes: "Pair", no: "Cancel" };
    }
    return { line: who + " asks something FART can't answer yet.", field: "", yes: "", no: "Cancel" };
}

function band(b) {
    return b ? b + " GHz" : "";
}

// 0..1 → "62 %", or "" for unknown.
function percent(level) {
    return level >= 0 ? Math.round(level * 100) + " %" : "";
}
