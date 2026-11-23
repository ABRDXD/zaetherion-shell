.pragma library

// DMS's two agent prompts, as plain values for the contract (docs/NET_BT.md §1, §4). Pure.
// `network.credentials` (NetworkManager wants a secret) and `bluetooth.pairing` (BlueZ wants a confirmation, PIN or
// passkey). The token stays in the adapter: the contract sees our own id. Secrets are built here only to be passed
// straight to the call; nothing here stores, logs or returns them except as that call's parameters.

const TIMEOUT = 90000;                // an unanswered prompt is cancelled after this
const WIFI_SETTING = "802-11-wireless-security";
const WIFI_SECRETS = ["psk", "wep-key0", "wep-key1", "wep-key2", "wep-key3"];
const PAIRING_KINDS = ["confirm", "display-passkey", "authorize", "pin", "passkey"];

// "psk": one Wi-Fi password · "vpn": one VPN password · "unsupported": anything else (802.1X identity, certificates…)
function credentialKind(data) {
    const fields = Array.isArray(data.fields) ? data.fields : [];
    const info = Array.isArray(data.fieldsInfo) ? data.fieldsInfo : [];
    const setting = data.setting || WIFI_SETTING;
    if (setting === WIFI_SETTING && fields.length <= 1 && (fields.length === 0 || WIFI_SECRETS.indexOf(fields[0]) >= 0)
            && info.length === 0)
        return "psk";
    const secretInfo = info.filter(f => f && f.isSecret === true);
    if ((data.connType === "vpn" || setting === "vpn") && info.length === secretInfo.length && (secretInfo.length === 1
            || (info.length === 0 && fields.length === 1)))
        return "vpn";
    return "unsupported";
}

// The event → a prompt, or null if it carries no token. `seq` makes our id; `timeoutMs` defaults to TIMEOUT.
function credential(data, now, seq, timeoutMs) {
    if (!data || typeof data.token !== "string" || data.token === "") return null;
    const fields = Array.isArray(data.fields) && data.fields.length ? data.fields : ["psk"];
    const info = Array.isArray(data.fieldsInfo) ? data.fieldsInfo : [];
    const secretField = info.find(f => f && f.isSecret === true)?.name ?? fields[0];
    return {
        id: "net-" + seq, token: data.token, deadline: now + (timeoutMs || TIMEOUT),
        ssid: String(data.ssid ?? ""), name: String(data.name ?? data.connectionId ?? data.ssid ?? ""),
        reason: String(data.reason ?? ""), kind: credentialKind(data), field: String(secretField)
    };
}

function credentialParams(prompt, secret) {
    const secrets = {};
    secrets[prompt.field] = secret;
    return { token: prompt.token, secrets: secrets, save: true };
}

function pairing(data, now, seq, timeoutMs) {
    if (!data || typeof data.token !== "string" || data.token === "") return null;
    const kind = PAIRING_KINDS.indexOf(data.requestType) >= 0 ? data.requestType : "unsupported";
    const shows = kind === "confirm" || kind === "display-passkey";
    const passkey = Number(data.passkey);
    return {
        id: "bt-" + seq, token: data.token, deadline: now + (timeoutMs || TIMEOUT), kind: kind,
        deviceName: String(data.deviceName ?? ""), device: String(data.deviceAddr ?? ""),
        // A number to compare on both screens, not a secret: six digits, zero-padded, as BlueZ shows it.
        passkey: shows && Number.isFinite(passkey) ? String(Math.trunc(passkey)).padStart(6, "0") : ""
    };
}

// Accepting only, as DMS's own dialog does; saying no is `bluetooth.pairing.cancel {token}`.
function pairingParams(prompt, code) {
    let secrets = { decision: "yes" };
    if (prompt.kind === "pin") secrets = { pin: code };
    else if (prompt.kind === "passkey") secrets = { passkey: code };
    return { token: prompt.token, secrets: secrets, accept: true };
}

function expired(prompt, now) {
    return !!prompt && now >= prompt.deadline;
}

function deadline(prompt) {
    return prompt ? prompt.deadline : -1;
}

// The contract's value: everything but the token and our clock.
function view(prompt) {
    if (!prompt) return null;
    const out = {};
    for (const key in prompt) if (key !== "token" && key !== "deadline" && key !== "field") out[key] = prompt[key];
    return out;
}
