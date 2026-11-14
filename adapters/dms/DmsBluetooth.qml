import QtQuick
import qs.adapters.quickshell
import qs.view.contract
import "DmsBluetoothMap.js" as BtMap
import "DmsAttempt.js" as Attempt
import "DmsPrompt.js" as Prompt
import "DmsSet.js" as Setter

// BluetoothDomain on DMS's `bluetooth` service and its BlueZ pairing agent (docs/NET_BT.md, Z190). State comes only
// from DMS's snapshots; battery levels alone come from Quickshell (DMS has none). One action per device at a time,
// each ending with a snapshot's outcome, DMS's error or a timeout. PINs and passkeys go straight into the call.
BluetoothDomain {
    id: root
    required property DmsLink link
    // BlueZ asks to confirm a passkey, or for a PIN; the island may show it while FART is closed.
    signal pairingArrived(string pairingId)

    // Un-leased: the island's glyph and the Devices tile read `enabled` with no lease.
    readonly property DmsFeed feed: DmsFeed { link: root.link; service: "bluetooth"; capability: "bluetooth"; wanted: true }
    readonly property DmsFeed pairingFeed: DmsFeed { link: root.link; service: "bluetooth.pairing"; capability: "bluetooth"; wanted: true }
    readonly property QuickshellBluetoothBattery battery: QuickshellBluetoothBattery {}

    property var snapshot: null
    property var powerState: Setter.initial()
    property var states: ({})          // device id -> DmsAttempt state
    property var pairingState: null
    property int pairingSeq: 0
    property bool discoveryAsked: false
    // Overridable for tests; the decided values are in DmsAttempt.js and DmsPrompt.js.
    property int connectTimeout: Attempt.timeout("bt-connect")
    property int pairTimeout: Attempt.timeout("bt-pair")
    property int otherTimeout: Attempt.timeout("bt-other")
    property int pairingTimeout: 0

    available: feed.usable && snapshot !== null
    enabled: BtMap.enabled(snapshot)
    discovering: BtMap.discovering(snapshot)
    readonly property var devicesNow: BtMap.devices(snapshot, address => battery.levelOf(address))
    onDevicesNowChanged: if (!BtMap.same(devicesNow, devices)) devices = devicesNow
    primary: devices.find(d => d.connected && d.audio) ?? devices.find(d => d.connected) ?? null
    readonly property var nearbyNow: BtMap.nearby(snapshot, holds("scan"))
    onNearbyNowChanged: if (!BtMap.same(nearbyNow, nearby)) nearby = nearbyNow
    attempts: {
        const out = {};
        for (const id in states) if (states[id]) out[id] = Attempt.view(states[id]);
        return out;
    }
    pairing: Prompt.view(pairingState)

    Connections {
        target: root.feed
        function onDataChanged() { root.snapshot = root.feed.data; }
    }
    Component.onCompleted: snapshot = feed.data

    function put(id, state) {
        const next = Object.assign({}, states);
        if (state) next[id] = state; else delete next[id];
        states = next;
    }
    function each(fn) {
        const next = {};
        for (const id in states) { const s = fn(states[id], id); if (s) next[id] = s; }
        states = next;
    }

    onSnapshotChanged: {
        if (snapshot === null) return;
        const now = Date.now();
        each(s => Attempt.observe(s, BtMap.observation(snapshot, s), now));
    }
    onAvailableChanged: if (!available) {
        powerState = Setter.initial();
        each(s => Attempt.linkDown(s));
        pairingState = null;            // its token died with the connection
        discoveryAsked = false;
    }

    function reread() {
        link.call("bluetooth.getState", undefined, (result, error) => {
            if (error === "" && result && typeof result === "object" && feed.usable) snapshot = result;
        });
    }

    // ---- Power: explicit value, one call in flight, the newest wish sent after the answer.
    function setEnabled(on: bool) {
        if (!available) return;
        const next = Setter.request(powerState, on, enabled);
        powerState = next.state;
        if (next.send !== null) sendPower(next.send);
    }
    function sendPower(on) {
        link.call("bluetooth.setPowered", { powered: on, adapter: BtMap.adapterPath(snapshot) }, (result, error) => {
            if (error !== "") console.warn("dms: bluetooth.setPowered failed:", error);
            const next = Setter.answered(powerState, BtMap.enabled(snapshot));
            powerState = next.state;
            if (next.send !== null) sendPower(next.send);
            else reread();
        }, otherTimeout);
    }

    // ---- Device actions.
    function act(id, action, method, timeoutMs) {
        if (!available) return;
        const path = BtMap.pathOf(snapshot, id);
        if (path === "") return;
        const next = Attempt.begin(states[id] ?? null, id, action, Date.now(), timeoutMs);
        if (!next.send) return;
        put(id, next.state);
        link.call(method, { device: path }, (result, error) => {
            if (error !== "") console.warn("dms:", method, "failed:", error);
            put(id, Attempt.replied(states[id] ?? null, error, Date.now()));
            if (error === "") reread();
        }, timeoutMs);
    }
    function device(id) { return devices.find(d => d.id === id) ?? null; }
    function connect(id: string) {
        const d = device(id);
        if (d && !d.connected) act(id, "connect", "bluetooth.connect", connectTimeout);
    }
    function disconnect(id: string) {
        const d = device(id);
        if (d && d.connected) act(id, "disconnect", "bluetooth.disconnect", connectTimeout);
    }
    function pair(id: string) {
        if (!device(id)) act(id, "pair", "bluetooth.pair", pairTimeout);
    }
    function trust(id: string, on: bool) {
        const d = device(id);
        if (d && d.trusted !== on) act(id, on ? "trust:on" : "trust:off", on ? "bluetooth.trust" : "bluetooth.untrust", otherTimeout);
    }
    function forget(id: string) {
        if (device(id)) act(id, "forget", "bluetooth.remove", otherTimeout);
    }
    function dismissAttempt(id: string) {
        if (states[id] && !Attempt.busy(states[id])) put(id, null);
    }

    // ---- Pairing prompts (bluetooth.pairing). One open at a time: a newer one replaces it, as in DMS.
    Connections {
        target: root.pairingFeed
        function onDataChanged() { root.pairingHeard(root.pairingFeed.data); }
    }
    function pairingHeard(data) {
        if (!data || (pairingState && pairingState.token === data.token)) return;
        const next = Prompt.pairing(data, Date.now(), pairingSeq + 1, pairingTimeout);
        if (!next) return;
        if (pairingState) link.call("bluetooth.pairing.cancel", { token: pairingState.token }, () => {});
        pairingSeq += 1;
        pairingState = next;
        // The device's attempt now waits for the person.
        if (states[next.device]) put(next.device, Attempt.rearm(states[next.device], Date.now()));
        pairingArrived(next.id);
    }
    function answerPairing(pairingId: string, code: string) {
        if (!available || !pairingState || pairingState.id !== pairingId) return;
        const needsCode = pairingState.kind === "pin" || pairingState.kind === "passkey";
        if (needsCode && code === "") return;
        const params = Prompt.pairingParams(pairingState, code);
        pairingState = null;            // answered once; a second click finds nothing
        link.call("bluetooth.pairing.submit", params, (result, error) => {
            if (error !== "") console.warn("dms: bluetooth.pairing.submit failed:", error);
        });
    }
    function cancelPairing(pairingId: string) {
        if (pairingState && pairingState.id === pairingId) closePairing("user-canceled");
    }
    function closePairing(reason) {
        const token = pairingState.token, id = pairingState.device;
        pairingState = null;
        if (states[id]) put(id, Attempt.cancel(states[id], Date.now(), reason));
        if (available) link.call("bluetooth.pairing.cancel", { token: token }, () => {});
    }

    // ---- Deadlines.
    DmsDeadline {
        at: {
            const all = Object.keys(root.states).map(id => Attempt.nextDeadline(root.states[id]))
                .concat([Prompt.deadline(root.pairingState)]).filter(t => t >= 0);
            return all.length ? Math.min.apply(null, all) : -1;
        }
        onDue: root.tick()
    }
    function tick() {
        const now = Date.now();
        if (pairingState && Prompt.expired(pairingState, now)) closePairing("prompt-timeout");
        each(s => Attempt.tick(s, now));
    }

    // Lease "scan": discovery runs while it is held (and again after DMS comes back), and stops when released.
    readonly property bool scanWanted: holds("scan") && available && enabled
    onScanWantedChanged: {
        if (scanWanted && !discoveryAsked) {
            discoveryAsked = true;
            link.call("bluetooth.startDiscovery", { adapter: BtMap.adapterPath(snapshot) }, (result, error) => {
                if (error !== "") console.warn("dms: bluetooth.startDiscovery failed:", error);
            });
        } else if (!scanWanted && discoveryAsked) {
            discoveryAsked = false;
            if (available)
                link.call("bluetooth.stopDiscovery", { adapter: BtMap.adapterPath(snapshot) }, (result, error) => {
                    if (error !== "") console.warn("dms: bluetooth.stopDiscovery failed:", error);
                });
        }
    }
}
