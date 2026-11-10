import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import qs.view.contract

NetworkDomain {
    id: root
    readonly property var device: Networking.devices.values.find(d => d.connected) ?? null
    readonly property var wifi: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var network: device?.networks?.values.find(n => n.connected) ?? null
    property string probedDevice: ""
    available: true
    wifiEnabled: Networking.wifiEnabled
    kind: device?.type === DeviceType.Wired ? "ethernet" : device?.type === DeviceType.Wifi ? "wifi" : "none"
    connected: device !== null
    name: network?.name || device?.name || ""
    networks: holds("scan") && wifi ? wifi.networks.values.map(n => ({ id: n.name, ssid: n.name, strength: n.signalStrength ?? 0,
        secured: (n.security ?? 0) !== 0, known: n.known, connected: n.connected })) : []
    Binding { target: root.wifi; property: "scannerEnabled"; value: root.holds("scan"); when: root.wifi !== null }

    function setWifiEnabled(on: bool) { Networking.wifiEnabled = on; }
    // Only remembered networks connect from FART; new ones need the host's credential dialog.
    function connect(networkId: string) {
        const target = wifi?.networks.values.find(n => n.name === networkId);
        if (target?.known) target.connect();
        else Quickshell.execDetached(["serpantinum", "msg", "open", "network", "wifi"]);
    }
    function probe() {
        if (!holds("details") || !device || probedDevice === device.name) return;
        probedDevice = device.name;
        ipAddress = "";
        addressProbe.running = true;
    }
    onDeviceChanged: { probedDevice = ""; ipAddress = ""; probe(); }
    onLeasesChanged: probe()
    Process {
        id: addressProbe
        command: ["ip", "-j", "address", "show", "dev", root.probedDevice]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text).find(d => d.ifname === root.probedDevice);
                    root.ipAddress = d?.addr_info.find(a => a.family === "inet" && a.scope === "global")?.local ?? "";
                } catch (_) { root.ipAddress = ""; }
            }
        }
    }
}
