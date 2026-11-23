import QtQuick
import qs.view.contract
import "DmsNetworkMap.js" as NetworkMap
import "DmsToggle.js" as Toggle
import "DmsAttempt.js" as Attempt
import "DmsPrompt.js" as Prompt

// NetworkDomain on DMS's `network` service (docs/DMS_ADAPTER.md §4, docs/NET_BT.md). Outcomes reach the view only
// through the properties below, which come from DMS's snapshots; there are no optimistic updates. Secrets pass
// through join() and answerPrompt() straight into the call's parameters and are never kept, logged or shown.
NetworkDomain {
    id: root
    required property DmsLink link
    // connect() on a network DMS has no saved profile for: passwords live in settings (Z95), so the root opens it.
    signal unknownNetwork(string networkId)
    // NetworkManager asks for a password; the island may show it while FART is closed.
    signal promptArrived(string promptId)

    // Un-leased state needs change events (the island's glyph, Z126), so this feed is wanted as long as we exist.
    readonly property DmsFeed feed: DmsFeed { link: root.link; service: "network"; capability: "network"; wanted: true }
    // NetworkManager's secret agent is DMS's backend; its prompts must be heard whether or not FART is open.
    readonly property DmsFeed credentialsFeed: DmsFeed { link: root.link; service: "network.credentials"; capability: "network"; wanted: true }
    // Resume (Z192 §6): preparingForSleep going false.
    readonly property DmsFeed sessionFeed: DmsFeed { link: root.link; service: "loginctl"; capability: "loginctl"; wanted: true }

    // The latest state DMS gave: its event, or the answer to our own getState after an action DMS sends no event for.
    property var snapshot: null
    property var toggleState: Toggle.initial()
    property bool scanning: false
    property var wifiState: null
    property var vpnState: null
    property var promptState: null
    property int promptSeq: 0
    // Overridable for tests; the decided values are in DmsAttempt.js and DmsPrompt.js.
    property int wifiTimeout: Attempt.timeout("wifi")
    property int vpnTimeout: Attempt.timeout("vpn")
    property int promptTimeout: 0

    available: feed.usable && snapshot !== null
    wifiEnabled: Toggle.current(toggleState, NetworkMap.wifiEnabled(snapshot))
    kind: NetworkMap.kind(snapshot)
    connected: kind !== "none"
    name: NetworkMap.name(snapshot)
    ipAddress: NetworkMap.ipAddress(snapshot, holds("details"))
    connecting: NetworkMap.connecting(snapshot)
    wired: NetworkMap.wired(snapshot)
    preference: snapshot && typeof snapshot.preference === "string" ? snapshot.preference : ""
    attempt: Attempt.view(wifiState)
    vpnAttempt: Attempt.view(vpnState)
    prompt: Prompt.view(promptState)

    // Lists are replaced only when their content changes.
    readonly property var nearby: NetworkMap.networks(snapshot, holds("scan"))
    onNearbyChanged: if (!NetworkMap.sameNetworks(nearby, networks)) networks = nearby
    readonly property var savedNow: NetworkMap.saved(snapshot, holds("saved"))
    onSavedNowChanged: if (!NetworkMap.sameNetworks(savedNow, saved)) saved = savedNow
    readonly property var vpnsNow: NetworkMap.vpn(snapshot)
    onVpnsNowChanged: if (!NetworkMap.sameNetworks(vpnsNow, vpns)) vpns = vpnsNow

    Connections {
        target: root.feed
        function onDataChanged() { root.snapshot = root.feed.data; }
    }
    Component.onCompleted: snapshot = feed.data

    onSnapshotChanged: {
        // The newest snapshot supersedes a toggle's answer.
        toggleState = Toggle.snapshot(toggleState);
        if (snapshot === null) return;
        const now = Date.now();
        wifiState = Attempt.observe(wifiState, NetworkMap.wifiObservation(snapshot, wifiState), now);
        vpnState = Attempt.observe(vpnState, NetworkMap.vpnObservation(snapshot, vpnState), now);
    }
    onAvailableChanged: if (!available) {
        toggleState = Toggle.initial();
        wifiState = Attempt.linkDown(wifiState);
        vpnState = Attempt.linkDown(vpnState);
        promptState = null;             // its token died with the connection
    }

    function setWifiEnabled(on: bool) {
        if (!available) return;
        const next = Toggle.request(toggleState, on, NetworkMap.wifiEnabled(snapshot));
        toggleState = next.state;
        if (next.flip) flip();
    }
    function flip() {
        link.call("network.wifi.toggle", undefined, (result, error) => {
            if (error !== "" || typeof result?.enabled !== "boolean") {
                console.warn("dms: network.wifi.toggle failed:", error !== "" ? error : "unexpected answer");
                toggleState = Toggle.failed(toggleState).state;
                return;
            }
            const next = Toggle.answered(toggleState, result.enabled);
            toggleState = next.state;
            if (next.flip) flip();
        });
    }

    // ---- Wi-Fi actions: one at a time (DmsAttempt.begin); each ends with a snapshot's outcome or a timeout.
    // `refresh`: DMS sends no event for this change (its own UI asks again), so we read the state after the answer.
    function wifiAction(target, action, method, params, refresh) {
        if (!available) return;
        const next = Attempt.begin(wifiState, target, action, Date.now(), wifiTimeout);
        if (!next.send) return;
        wifiState = next.state;
        link.call(method, params, (result, error) => {
            if (error !== "") console.warn("dms:", method, "failed:", error);
            wifiState = Attempt.replied(wifiState, error, Date.now());
            if (error === "" && refresh) reread();
        }, wifiTimeout);
    }
    function reread() {
        link.call("network.getState", undefined, (result, error) => {
            if (error === "" && result && typeof result === "object" && feed.usable) snapshot = result;
        });
    }

    function connect(networkId: string) {
        if (!available) return;
        const action = NetworkMap.connectAction(snapshot, networkId);
        if (action === "connect")
            wifiAction(networkId, "connect", "network.wifi.connect", { ssid: networkId, interactive: false }, false);
        else if (action === "unknown")
            unknownNetwork(networkId);
        else if (action === "enterprise")
            refuse(networkId, "connect", "enterprise");
    }
    // A network FART can't join (802.1X): said so at once, nothing sent.
    function refuse(target, action, reason) {
        const next = Attempt.begin(wifiState, target, action, Date.now(), wifiTimeout);
        if (next.send) wifiState = Attempt.replied(next.state, reason, Date.now());
    }
    function join(ssid: string, secret: string, hidden: bool) {
        if (!available || ssid === "") return;
        const action = NetworkMap.connectAction(snapshot, ssid);
        if (action === "none") return;                  // already on it
        if (action === "enterprise") return refuse(ssid, "join", "enterprise");
        const params = { ssid: ssid, interactive: false };
        if (secret !== "") params.password = secret;
        if (hidden) params.hidden = true;
        wifiAction(ssid, "join", "network.wifi.connect", params, false);
    }
    function disconnect() {
        if (!available || snapshot?.wifiConnected !== true) return;
        wifiAction(String(snapshot.wifiSSID ?? ""), "disconnect", "network.wifi.disconnect", undefined, false);
    }
    function forget(networkId: string) {
        if (networkId !== "") wifiAction(networkId, "forget", "network.wifi.forget", { ssid: networkId }, true);
    }
    function setAutoconnect(networkId: string, on: bool) {
        if (networkId !== "")
            wifiAction(networkId, on ? "autoconnect:on" : "autoconnect:off", "network.wifi.setAutoconnect",
                       { ssid: networkId, autoconnect: on }, true);
    }
    function setPreference(value: string) {
        if (!available || ["auto", "wifi", "ethernet"].indexOf(value) < 0 || value === preference) return;
        link.call("network.preference.set", { preference: value }, (result, error) => {
            if (error !== "") console.warn("dms: network.preference.set failed:", error);
            else reread();
        });
    }
    function setVpn(vpnId: string, on: bool) {
        if (!available || vpnId === "") return;
        const next = Attempt.begin(vpnState, vpnId, on ? "vpn:on" : "vpn:off", Date.now(), vpnTimeout);
        if (!next.send) return;
        vpnState = next.state;
        const method = on ? "network.vpn.connect" : "network.vpn.disconnect";
        const params = on ? { uuidOrName: vpnId, singleActive: false } : { uuidOrName: vpnId };
        link.call(method, params, (result, error) => {
            if (error !== "") console.warn("dms:", method, "failed:", error);
            vpnState = Attempt.replied(vpnState, error, Date.now());
        }, vpnTimeout);
    }
    function dismissAttempt() {
        if (!Attempt.busy(wifiState) && wifiState?.phase !== "wrong-secret") wifiState = null;
        if (!Attempt.busy(vpnState)) vpnState = null;
    }

    // ---- Password prompts (network.credentials). One open at a time: a newer one replaces it, as in DMS.
    Connections {
        target: root.credentialsFeed
        function onDataChanged() { root.promptHeard(root.credentialsFeed.data); }
    }
    function promptHeard(data) {
        if (!data || (promptState && promptState.token === data.token)) return;
        const next = Prompt.credential(data, Date.now(), promptSeq + 1, promptTimeout);
        if (!next) return;
        if (promptState) link.call("network.credentials.cancel", { token: promptState.token }, () => {});
        promptSeq += 1;
        promptState = next;
        const now = Date.now();
        // Its network's attempt now waits for the person, not for NetworkManager.
        if (wifiState && wifiState.target === next.ssid)
            wifiState = next.reason === "wrong-password"
                ? Attempt.observe(wifiState, { ok: false, progress: false, reason: "bad-credentials", wrongSecret: true }, now)
                : Attempt.rearm(wifiState, now);
        promptArrived(next.id);
    }
    function answerPrompt(promptId: string, secret: string) {
        if (!available || !promptState || promptState.id !== promptId) return;
        const params = Prompt.credentialParams(promptState, secret);
        const ssid = promptState.ssid;
        promptState = null;             // answered once; a second click finds nothing
        if (wifiState && wifiState.target === ssid) wifiState = Attempt.retry(wifiState, Date.now());
        link.call("network.credentials.submit", params, (result, error) => {
            if (error !== "") console.warn("dms: network.credentials.submit failed:", error);
        });
    }
    function cancelPrompt(promptId: string) {
        if (!promptState || promptState.id !== promptId) return;
        closePrompt("user-canceled");
    }
    function closePrompt(reason) {
        const token = promptState.token, ssid = promptState.ssid;
        promptState = null;
        if (wifiState && wifiState.target === ssid) wifiState = Attempt.cancel(wifiState, Date.now(), reason);
        if (available) link.call("network.credentials.cancel", { token: token }, () => {});
    }

    // ---- Deadlines: attempts, the open prompt.
    DmsDeadline {
        at: {
            const all = [Attempt.nextDeadline(root.wifiState), Attempt.nextDeadline(root.vpnState), Prompt.deadline(root.promptState)]
                .filter(t => t >= 0);
            return all.length ? Math.min.apply(null, all) : -1;
        }
        onDue: root.tick()
    }
    function tick() {
        const now = Date.now();
        if (promptState && Prompt.expired(promptState, now)) closePrompt("prompt-timeout");
        wifiState = Attempt.tick(wifiState, now);
        vpnState = Attempt.tick(vpnState, now);
    }

    // ---- Resume: time asleep doesn't count, and a held scan runs again (NetworkManager reconnects by itself).
    readonly property bool sleeping: sessionFeed.data?.preparingForSleep === true
    onSleepingChanged: if (!sleeping) {
        const now = Date.now();
        wifiState = Attempt.rearm(wifiState, now);
        vpnState = Attempt.rearm(vpnState, now);
        if (scanWanted) startScan();
    }

    // Lease "scan": one scan per rising edge of held && available && wifiEnabled, one in flight; results arrive in snapshots.
    readonly property bool scanWanted: holds("scan") && available && wifiEnabled
    onScanWantedChanged: if (scanWanted) startScan()
    function startScan() {
        if (scanning) return;
        scanning = true;
        link.call("network.wifi.scan", undefined, (result, error) => {
            scanning = false;
            if (error !== "") console.warn("dms: network.wifi.scan failed:", error);
        });
    }
}
