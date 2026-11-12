import QtQuick
import qs.view.contract
import "DmsNetworkMap.js" as NetworkMap
import "DmsToggle.js" as Toggle

// NetworkDomain on DMS's `network` service (docs/DMS_ADAPTER.md §4). Outcomes reach the view only through the
// properties below, which come from DMS's snapshots; there are no optimistic updates.
NetworkDomain {
    id: root
    required property DmsLink link
    // connect() on a network DMS has no saved profile for: passwords live in settings (Z95), so the root opens it.
    signal unknownNetwork(string networkId)

    // Un-leased state needs change events (the island's glyph, Z126), so this feed is wanted as long as we exist.
    readonly property DmsFeed feed: DmsFeed { link: root.link; service: "network"; capability: "network"; wanted: true }
    readonly property var snapshot: feed.data
    property var toggleState: Toggle.initial()
    property bool scanning: false

    available: feed.usable && snapshot !== null
    wifiEnabled: Toggle.current(toggleState, NetworkMap.wifiEnabled(snapshot))
    kind: NetworkMap.kind(snapshot)
    connected: kind !== "none"
    name: NetworkMap.name(snapshot)
    ipAddress: NetworkMap.ipAddress(snapshot, holds("details"))

    // Replaced only when its content changes.
    readonly property var nearby: NetworkMap.networks(snapshot, holds("scan"))
    onNearbyChanged: if (!NetworkMap.sameNetworks(nearby, networks)) networks = nearby

    // The newest snapshot supersedes a toggle's answer.
    onSnapshotChanged: toggleState = Toggle.snapshot(toggleState)
    onAvailableChanged: if (!available) toggleState = Toggle.initial()

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

    function connect(networkId: string) {
        if (!available) return;
        const action = NetworkMap.connectAction(snapshot, networkId);
        if (action === "connect") {
            link.call("network.wifi.connect", { ssid: networkId, interactive: false }, (result, error) => {
                if (error !== "") console.warn("dms: network.wifi.connect failed:", error);
            });
        } else if (action === "unknown") {
            unknownNetwork(networkId);
        }
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
