// WifiNetwork: { id, ssid, strength, secured, known, connected }.
HostDomain {
    property bool wifiEnabled: false
    property string kind: "none"
    property bool connected: false
    property string name: ""
    // Lease "details": one address probe per device change.
    property string ipAddress: ""
    // Lease "scan": nearby networks for quick connect.
    property var networks: []

    function setWifiEnabled(on: bool) { record("setWifiEnabled", [on]); }
    function connect(networkId: string) { record("connect", [networkId]); }
}
