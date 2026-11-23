// WifiNetwork: { id, ssid, strength, secured, known, connected, enterprise, hidden, autoconnect, band ("2.4"|"5"|"6"|"") }.
// Attempt: { target, action, phase, reason } (docs/NET_BT.md §3): phase working · lost · done · wrong-secret · timeout ·
// failed · cancelled. Prompt: { id, ssid, name, reason, kind ("psk"|"vpn"|"unsupported") }; it never carries a secret.
HostDomain {
    property var airplaneMode: null
    property bool wifiEnabled: false
    property string kind: "none"
    property bool connected: false
    property string name: ""
    // Lease "details": one address probe per device change.
    property string ipAddress: ""
    // Lease "scan": nearby networks for quick connect.
    property var networks: []
    // Lease "saved": [{ id, ssid, autoconnect, inRange, enterprise, connected }] for the settings list.
    property var saved: []
    // The network NetworkManager is joining right now, or "".
    property string connecting: ""
    property var wired: ({ connected: false, name: "" })
    // [{ id, name, state ("on"|"starting"|"off") }].
    property var vpns: []
    // "auto" | "wifi" | "ethernet", or "" when the host has no preference.
    property string preference: ""
    property var attempt: null
    property var vpnAttempt: null
    property var prompt: null

    function setWifiEnabled(on: bool) { record("setWifiEnabled", [on]); }
    function connect(networkId: string) { record("connect", [networkId]); }
    // A new network. The secret goes straight to the host and is never recorded, even in a fixture's call log.
    function join(ssid: string, secret: string, hidden: bool) { record("join", [ssid, "", hidden]); }
    function disconnect() { record("disconnect", []); }
    function forget(networkId: string) { record("forget", [networkId]); }
    function setAutoconnect(networkId: string, on: bool) { record("setAutoconnect", [networkId, on]); }
    function setPreference(value: string) { record("setPreference", [value]); }
    function setVpn(vpnId: string, on: bool) { record("setVpn", [vpnId, on]); }
    function answerPrompt(promptId: string, secret: string) { record("answerPrompt", [promptId, ""]); }
    function cancelPrompt(promptId: string) { record("cancelPrompt", [promptId]); }
    function dismissAttempt() { record("dismissAttempt", []); }
}
