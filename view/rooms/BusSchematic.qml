import qs.core.client
import qs.view.cues
import qs.view.ui
import QtQuick
import "Buses.js" as B

// The machine's USB as it is wired (docs/OVERDRIVE.md §38; atlas #21), the Stratum `devices.buses` in the spare foot of
// Devices' Sound & Light column, Overdrive only: one column per controller, its root hubs as rails (USB 2 a hairline,
// USB 3 heavy), each port a tap: open, or ending in what is plugged in (kind, speed, product), a hub's ports indented
// under it. A port that held something this session keeps its ghost; a device plugged in while this is up is inked in
// the accent for 12 s. The Bluetooth devices linked hang off the radio as a wireless island, and the audio endpoints
// stand in a column of their own (the room's lists, passed in). The core reads sysfs only while this asks (`bus.usb`, every 3 s; core/buses.py).
Item {
    id: root
    property CoreClient core: null
    // False only in tests, which call take() themselves.
    property bool autonomous: true
    property var reading: null
    // The room's own lists: the Bluetooth devices and the audio endpoints (not read again).
    property var bluetooth: []
    property var outputs: []
    property var inputs: []
    property var streams: []
    // The session's memory of the ports (kept in Buses.js, so it outlives Overdrive's release), and this look's start.
    property var memory: B.kept.memory
    property double since: -1
    property double now: Date.now()
    readonly property var columns: B.all(reading, bluetooth, outputs, inputs, streams, memory)
    readonly property int most: columns.reduce((m, c) => Math.max(m, c.rows.length), 1)
    readonly property real header: 16
    readonly property real rowHeight: Math.max(9, Math.min(17, (height - header - 2) / most))
    // A controller with nothing plugged in (and no ghost) takes a narrow column; the others share the rest.
    readonly property var busy: columns.map(c => c.rows.some(r => r.device || memory[r.path]))
    readonly property real narrow: 52
    readonly property real wide: { const n = busy.filter(b => b).length; return n ? (width - narrow * (columns.length - n)) / n : width; }
    function columnX(i) { let x = 0; for (let k = 0; k < i; k++) x += busy[k] ? wide : narrow; return x; }
    opacity: Motion.drive

    Timer {
        interval: 3000
        repeat: true
        running: root.autonomous
        triggeredOnStart: true
        onTriggered: root.core?.request("bus.usb", {}, (ok, result) => { if (ok && result && root) root.take(result, Date.now()); })
    }
    function take(r, at) {
        if (!r || !r.running)
            return;
        reading = r;
        look(at);
    }
    // Remember what is plugged in, linked and connected now.
    function look(at) {
        now = at;
        if (since < 0)
            since = at;
        B.kept.memory = B.remember(B.kept.memory, B.present(reading, bluetooth, outputs, inputs), at);
        memory = B.kept.memory;
    }
    onBluetoothChanged: if (reading) look(Date.now())
    onOutputsChanged: if (reading) look(Date.now())
    onInputsChanged: if (reading) look(Date.now())

    Repeater {
        model: root.columns
        Item {
            id: column
            required property var modelData
            required property int index
            readonly property bool used: root.busy[index] ?? true
            x: root.columnX(index)
            width: (used ? root.wide : root.narrow) - 10
            height: root.height
            // The controller: its place on the PCI bus.
            FText {
                text: column.modelData.pci === "AUDIO" ? "AUDIO" : (column.used ? "XHCI " : "") + (column.modelData.pci.split(":").slice(-2).join(":"))
                width: column.width
                elide: Text.ElideRight
                technical: true
                voice: "kernel"
                color: Design.faint
                font.pixelSize: Design.caption
            }
            // The rails, from under the header to the last tap.
            Repeater {
                model: column.modelData.rails
                Rectangle {
                    required property var modelData
                    required property int index
                    readonly property var mine: column.modelData.rows.map((r, i) => r.rail === index ? i : -1).filter(i => i >= 0)
                    x: 2 + index * 6
                    y: root.header
                    width: B.weight(modelData)
                    height: mine.length ? (mine[mine.length - 1] + 0.5) * root.rowHeight : 0
                    color: index === 0 ? Design.muted : Design.ink
                }
            }
            Repeater {
                model: column.modelData.rows
                Item {
                    id: row
                    required property var modelData
                    required property int index
                    readonly property string state: B.state(modelData, root.memory, root.now, root.since)
                    readonly property var ghost: root.memory[modelData.path] ?? null
                    readonly property real railX: 2 + modelData.rail * 6
                    readonly property real tapX: railX + 10 + modelData.depth * 10
                    readonly property color ink: state === "fresh" ? Design.accent : state === "device" ? Design.ink : Design.faint
                    y: root.header + index * root.rowHeight
                    width: column.width
                    height: root.rowHeight
                    // The tap: from the rail (or the hub above it) to the port.
                    Rectangle {
                        x: row.modelData.depth > 0 ? row.tapX - 10 : row.railX
                        y: Math.round(row.height / 2)
                        width: row.tapX - x + (row.state === "open" || row.state === "ghost" ? 0 : 4)
                        height: row.state === "device" || row.state === "fresh" ? B.weight(row.modelData.speed) : 1
                        color: row.ink
                        opacity: row.state === "open" ? 0.5 : 1
                    }
                    // A wireless tap (the Bluetooth island) is broken: gaps cut across it.
                    Repeater {
                        model: row.modelData.wireless ? Math.floor((row.tapX - (row.tapX - 10)) / 3) : 0
                        Rectangle {
                            required property int index
                            x: row.tapX - 10 + index * 3 + 2
                            y: Math.round(row.height / 2) - 1
                            width: 1
                            height: 3
                            color: Design.background
                        }
                    }
                    // A hub's own ports hang from a short drop under it.
                    Rectangle {
                        visible: row.modelData.depth > 0
                        x: row.tapX - 10
                        y: -row.height / 2
                        width: 1
                        height: row.height
                        color: Design.faint
                    }
                    // Open: an unterminated stub. Plugged in: a node and the device. A ghost: what was here, and when it left.
                    Rectangle {
                        visible: row.state === "open" || row.state === "ghost"
                        x: row.tapX
                        y: Math.round(row.height / 2) - 2
                        width: 1
                        height: 5
                        color: Design.faint
                    }
                    Rectangle {
                        visible: row.state === "device" || row.state === "fresh"
                        x: row.tapX + 4
                        y: Math.round(row.height / 2) - 2
                        width: 5
                        height: 5
                        color: row.ink
                    }
                    FText {
                        x: row.tapX + 13
                        width: row.width - x
                        anchors.verticalCenter: parent.verticalCenter
                        visible: row.state !== "open" && root.rowHeight >= 10
                        text: row.state === "ghost"
                            ? (row.ghost?.kind ?? "") + " · OUT " + B.clock(row.ghost?.out ?? 0)
                            : row.modelData.device ? [row.modelData.device.kind, B.speedTag(row.modelData.device.speed)].filter(t => t).join(" ") + (row.width > 150 ? " · " + row.modelData.device.product : "") : ""
                        technical: true
                        font.pixelSize: Math.min(Design.caption, Math.round(root.rowHeight * 0.8)) // scale: the row's height
                        elide: Text.ElideRight
                        color: row.ink
                        opacity: row.state === "ghost" ? 0.55 : 1
                    }
                }
            }
        }
    }
}
