// BtDevice: { id, name, kind, connected, paired, trusted, blocked, audio, battery } (battery 0..1, -1 = unknown).
// kind is a glyph name: headphones, speaker, mouse, keyboard, sports_esports, smartphone, watch, tv, computer, bluetooth.
// attempts: { <device id>: { target, action, phase, reason } } (docs/NET_BT.md §3).
// pairing: { id, kind ("confirm"|"display-passkey"|"authorize"|"pin"|"passkey"|"unsupported"), deviceName, device, passkey }.
HostDomain {
    property bool enabled: false
    property var devices: []
    property var primary: null
    property bool discovering: false
    // Lease "scan": unpaired devices nearby, [BtDevice + { strength }].
    property var nearby: []
    property var attempts: ({})
    property var pairing: null

    function setEnabled(on: bool) { record("setEnabled", [on]); }
    function connect(id: string) { record("connect", [id]); }
    function disconnect(id: string) { record("disconnect", [id]); }
    function pair(id: string) { record("pair", [id]); }
    function trust(id: string, on: bool) { record("trust", [id, on]); }
    function forget(id: string) { record("forget", [id]); }
    // The PIN or passkey typed, or "" for a confirmation; never recorded.
    function answerPairing(pairingId: string, code: string) { record("answerPairing", [pairingId, ""]); }
    function cancelPairing(pairingId: string) { record("cancelPairing", [pairingId]); }
    function dismissAttempt(id: string) { record("dismissAttempt", [id]); }
}
