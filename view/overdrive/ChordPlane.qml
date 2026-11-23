import qs.view.cues
import qs.view.ui
import QtQuick
import QtQuick.Layouts

// Chords (docs/OVERDRIVE_IDEAS.md #60): rooms combine. In the orbit, in Overdrive, hold C and tap two room numbers: the
// pair opens a working plane that belongs to neither room alone. Media + Devices routes the sound; Tasks + Timers
// starts work on the next task; Devices + Performance sets the power profile against the load; Workspaces +
// Performance shows the desks beside the CPU and goes to one. Every button acts only when clicked. A pair with no
// grammar says so. Esc closes it.
Item {
    id: root
    required property var host
    required property var core
    // The rooms chosen so far: `first` while waiting for the second, `pair` once there are two.
    property string first: ""
    property var pair: []
    property bool chording: false
    property var names: ({})
    signal closed()
    readonly property string key: pair.length === 2 ? [...pair].sort().join("+") : ""
    function has(id) { return pair.includes(id); }
    readonly property var grammar: ({
        "devices+media": { title: "ROUTE THE SOUND", line: "Where this plays from now on." },
        "tasks+timers": { title: "WORK THE NEXT TASK", line: "A countdown against what is next." },
        "devices+performance": { title: "POWER AGAINST LOAD", line: "How hard the machine is allowed to run." },
        "performance+workspaces": { title: "THE DESKS AND THE LOAD", line: "Where the work is, and what it costs." }
    })
    readonly property var entry: grammar[key] ?? null
    readonly property var sys: host?.system ?? null
    readonly property bool wantsLoad: key === "devices+performance" || key === "performance+workspaces"
    HostLease { domain: root.sys; feature: "resources"; active: root.wantsLoad }
    readonly property string load: sys?.cpu?.available ? "CPU " + Math.round((sys.cpu.usage ?? 0) * 100) + " %" : "CPU —"
    readonly property var nextTask: (core?.tasks?.all ?? []).find(t => !t.done) ?? null
    readonly property var wm: host?.workspaces ?? null

    // The strip while the chord is being played.
    Plane {
        visible: root.chording && root.pair.length === 0
        anchors.horizontalCenter: parent.horizontalCenter
        y: 12
        width: 300
        height: 30
        role: "signal"
        slant: 3
        backing: true
        FText {
            anchors.centerIn: parent
            text: root.first === "" ? "CHORD · TAP TWO ROOMS" : "CHORD · " + (root.names[root.first] ?? root.first).toUpperCase() + " +"
            technical: true
            color: parent.textColor
        }
    }
    Rectangle {
        id: plate
        visible: root.pair.length === 2
        anchors.centerIn: parent
        width: Math.min(parent.width - 48, 460)
        height: column.implicitHeight + 32
        color: Design.surface
        border.width: 1
        border.color: Design.accent
        MouseArea { anchors.fill: parent }
        ColumnLayout {
            id: column
            x: 16
            y: 16
            width: parent.width - 32
            spacing: 8
            RowLayout {
                Layout.fillWidth: true
                FText {
                    Layout.fillWidth: true
                    text: root.entry?.title ?? "NO GRAMMAR YET"
                    headline: true
                    font.pixelSize: Design.readout
                    font.weight: Font.Black
                    color: Design.accent
                }
                FButton {
                    symbol: "close"
                    implicitHeight: 26
                    hint: "Close (Esc)"
                    onClicked: root.closed()
                }
            }
            FText {
                Layout.fillWidth: true
                text: root.pair.map(id => (root.names[id] ?? id).toUpperCase()).join(" + ") + (root.entry ? "  ·  " + root.entry.line : "  ·  these two have nothing to say to each other")
                technical: true
                font.capitalization: Font.MixedCase
                wrapMode: Text.Wrap
                color: Design.muted
            }
            // Media + Devices: every output, the current one marked.
            Repeater {
                model: root.key === "devices+media" ? (root.host?.audio?.outputs ?? []) : []
                FButton {
                    required property var modelData
                    Layout.fillWidth: true
                    label: modelData.name
                    selected: modelData.isDefault === true
                    onClicked: root.host.audio.setDefault("output", modelData.id)
                }
            }
            // Tasks + Timers: the next task and three lengths.
            FText {
                visible: root.key === "tasks+timers"
                Layout.fillWidth: true
                text: root.nextTask ? root.nextTask.text : "Nothing is open. Work on nothing, then."
                font.pixelSize: Design.control
                wrapMode: Text.Wrap
                color: Design.ink
            }
            RowLayout {
                visible: root.key === "tasks+timers"
                Layout.fillWidth: true
                Repeater {
                    model: [15, 25, 45]
                    FButton {
                        required property int modelData
                        Layout.fillWidth: true
                        label: modelData + " MIN"
                        onClicked: { root.core.timers.startCountdown(modelData * 60); root.closed(); }
                    }
                }
            }
            // Devices + Performance: the load, and every power profile.
            FText {
                visible: root.wantsLoad
                text: root.load
                headline: true
                font.pixelSize: Design.readout
                font.weight: Font.Black
                color: Design.ink
            }
            Repeater {
                model: root.key === "devices+performance" ? (root.host?.power?.profiles ?? []) : []
                FButton {
                    required property string modelData
                    Layout.fillWidth: true
                    label: modelData
                    selected: root.host.power.profile === modelData
                    onClicked: root.host.power.setProfile(modelData)
                }
            }
            // Workspaces + Performance: the desks with windows on them.
            Repeater {
                model: root.key === "performance+workspaces" ? (root.wm?.workspaces ?? []).filter(w => (w.windowCount ?? 0) > 0) : []
                FButton {
                    required property var modelData
                    Layout.fillWidth: true
                    label: "Desk " + modelData.id + "  ·  " + modelData.windowCount + (modelData.windowCount === 1 ? " window" : " windows")
                    selected: String(root.wm.activeId) === String(modelData.id)
                    onClicked: root.wm.switchTo(String(modelData.id))
                }
            }
        }
    }
}
