import qs.view.contract
import qs.view.ui
import QtQuick

// Devices as a planet: the three links (network, Bluetooth, sound out) as glyphs, lit or faint; the
// network's name; the readout adds the Bluetooth device and the output. Recording is the alarm.
// Network and Bluetooth need no lease. The recorder's state does (a probe every 1.5 s, too costly
// for a face to keep), so the face holds that lease for one probe each time it becomes live, then
// lets it go. The output's mute and volume need the mixer, so they are not shown.
Face {
    id: root
    required property HostAdapter host
    readonly property var network: host.network
    readonly property var bluetooth: host.bluetooth
    readonly property bool recording: host.hostActions.recording.active
    readonly property var output: host.audio.outputs.find(o => o.isDefault) ?? null
    readonly property bool wired: network.kind === "ethernet"
    readonly property bool btOn: bluetooth.available && bluetooth.enabled
    readonly property var links: [
        { symbol: wired ? "lan" : network.wifiEnabled ? "wifi" : "wifi_off", on: network.connected, name: "network" },
        { symbol: !btOn ? "bluetooth_disabled" : bluetooth.primary ? "bluetooth_connected" : "bluetooth", on: btOn && !!bluetooth.primary, name: "bluetooth" },
        { symbol: output ? "volume_up" : "volume_off", on: !!output, name: "sound" }
    ]
    readonly property string line: !network.available ? "NO NETWORK" : network.connected ? (wired ? "WIRED" : network.name)
        : network.wifiEnabled ? "NOT CONNECTED" : "OFFLINE"

    note: recording ? "● REC · " + line : line
    alarm: recording
    detail: [btOn ? (bluetooth.primary?.name ?? "BT ON") : "BT OFF", output?.name ?? "NO OUTPUT"].join(" · ")
    figureItem: Component {
        Item {
            id: glyphs
            readonly property int size: Math.max(10, Math.min(48, Math.round(Math.min(root.figureSize, (root.width - (root.node ? (root.nodeSize + 3) * 2 : 0)) / 3.8))))
            implicitWidth: row.implicitWidth + (root.node ? (root.nodeSize + 3) * 2 : 0)
            implicitHeight: root.figureHeight
            Row {
                id: row
                anchors.centerIn: parent
                spacing: Math.round(glyphs.size * 0.3)
                Repeater {
                    model: root.links
                    MaterialSymbol {
                        required property var modelData
                        text: modelData.symbol
                        iconSize: glyphs.size
                        color: root.tone
                        opacity: modelData.on ? 1 : 0.38
                    }
                }
            }
            // At tier 0 the glyphs are all there is, so recording is a node beside them.
            Rectangle {
                visible: root.node
                x: row.x + row.width + 3
                y: Math.round(parent.height * 0.18)
                width: root.nodeSize
                height: width
                color: root.tone
            }
        }
    }

    // One recorder probe per time the face is shown: acquired on live, released after a second
    // (the adapter probes on acquire, and its next probe would be at 1.5 s).
    property bool probing: false
    function probe() {
        probing = live;
        if (live)
            probeWindow.restart();
    }
    onLiveChanged: probe()
    Component.onCompleted: probe()
    Timer { id: probeWindow; interval: 1000; onTriggered: root.probing = false }
    HostLease { domain: root.host.hostActions; feature: "recording"; active: root.probing }

    Accessible.role: Accessible.StaticText
    Accessible.name: links.map(l => l.name + (l.on ? " on" : " off")).join(", ") + (recording ? ", recording" : "")
}
