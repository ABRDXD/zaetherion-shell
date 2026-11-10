import qs.view.cues
import qs.view.strata
import qs.view.ui
import QtQuick
import QtQuick.Layouts

// The lease manager (M8, docs/OVERDRIVE.md §1): Overdrive's state and why, its four routes (this panel, 20 minutes,
// an hour, sticky) and the release; the guards that suspend it, each with whether this machine has it and whether
// it is on; the tiers (D3); and the engine: the drive, the strata that exist, the idle loops and the frames the
// panel is drawing. The frame counter runs only while this is open.
Rectangle {
    id: root
    required property OverdriveLease lease
    property Heat heat: null
    signal closed()
    implicitWidth: 330
    implicitHeight: column.implicitHeight + 32
    color: Design.surface
    radius: Design.radiusCard
    border.width: 1
    border.color: lease.requested ? Qt.alpha(Design.accent, 0.7) : Design.line
    property int frames: 0
    property int fps: 0
    property double now: Date.now()
    function ago(at) {
        const seconds = Math.max(0, Math.round((root.now - at) / 1000));
        return seconds < 60 ? seconds + " s ago" : Math.floor(seconds / 60) + " min ago";
    }
    Connections {
        target: root.Window.window
        enabled: root.visible
        function onFrameSwapped() { root.frames++; }
    }
    Timer {
        interval: 1000
        repeat: true
        running: root.visible
        onTriggered: { root.fps = root.frames; root.frames = 0; root.now = Date.now(); }
    }
    readonly property var guardRows: [
        { id: "fullscreen", name: "Fullscreen window", about: "a fullscreen window on the focused screen" },
        { id: "battery", name: "On battery", about: "running on battery (UPower)" },
        { id: "session", name: "Session", about: "a focus session forces Silent" }
    ]
    ColumnLayout {
        id: column
        x: 16
        y: 16
        width: parent.width - 32
        spacing: 8
        RowLayout {
            Layout.fillWidth: true
            FText {
                text: "OVERDRIVE"
                headline: true
                font.pixelSize: Design.readout
                font.weight: Font.Black
                color: root.lease.requested ? Design.accent : Design.ink
                Layout.fillWidth: true
            }
            FButton {
                symbol: "close"
                implicitHeight: 26
                hint: "Close the lease manager"
                onClicked: root.closed()
            }
        }
        FText {
            Layout.fillWidth: true
            text: !root.lease.requested ? "Silent. Nothing moves at rest."
                : Motion.reduced ? "Held, but motion is reduced: nothing moves and no effect exists until motion is back on."
                : root.lease.suspended ? "Suspended: " + root.lease.reason() + ". It comes back by itself when that ends."
                : "Running: " + ({ panel: "until this panel closes.", sticky: "until you release it.", timed: "until its time is up." })[root.lease.mode]
            wrapMode: Text.Wrap
            color: Design.muted
        }
        FText {
            Layout.fillWidth: true
            text: "Hold F/ in the header for 600 ms to ignite; hold it again to cut."
            technical: true
            aside: true
            font.capitalization: Font.MixedCase
            wrapMode: Text.Wrap
            color: Design.faint
        }
        FText { text: "LEASE"; technical: true; color: Design.faint; Layout.topMargin: 4 }
        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: 6
            rowSpacing: 6
            FButton {
                Layout.fillWidth: true
                label: "This panel"
                hint: "Overdrive until the panel closes"
                selected: root.lease.mode === "panel"
                onClicked: root.lease.request("panel")
            }
            FButton {
                Layout.fillWidth: true
                label: "Sticky"
                hint: "Overdrive until released, across closes (guards still suspend it)"
                selected: root.lease.mode === "sticky"
                onClicked: root.lease.request("sticky")
            }
            FButton {
                Layout.fillWidth: true
                label: "20 minutes"
                selected: root.lease.mode === "timed"
                onClicked: root.lease.request("timed", 20 * 60)
            }
            FButton {
                Layout.fillWidth: true
                label: "1 hour"
                onClicked: root.lease.request("timed", 60 * 60)
            }
        }
        FButton {
            Layout.fillWidth: true
            label: "Release · back to Silent"
            symbol: "power_settings_new"
            enabled: root.lease.requested
            onClicked: root.lease.release()
        }
        FButton {
            Layout.fillWidth: true
            label: "Forget my room history"
            symbol: "history_toggle_off"
            hint: "The orbit's shelves, routes and habits start again. Only rooms and times are ever kept."
            onClicked: root.lease.core.request("journey.forget", {})
        }
        FText { text: "GUARDS · ANY ONE ON SUSPENDS IT"; technical: true; color: Design.faint; Layout.topMargin: 4 }
        Repeater {
            model: root.guardRows
            RowLayout {
                id: guard
                required property var modelData
                readonly property bool available: root.lease.guards[modelData.id] === "available"
                readonly property bool on: root.lease.reasons.includes(modelData.id)
                Layout.fillWidth: true
                spacing: 8
                Rectangle {
                    implicitWidth: 7
                    implicitHeight: 7
                    color: guard.on ? Design.warm : "transparent"
                    border.width: 1
                    border.color: guard.on ? Design.warm : guard.available ? Design.muted : Design.line
                }
                FText {
                    text: guard.modelData.name
                    color: guard.on ? Design.warm : guard.available ? Design.ink : Design.faint
                    Layout.fillWidth: true
                }
                FText {
                    text: !root.lease.requested && !guard.on ? (guard.available || Object.keys(root.lease.guards).length === 0 ? "watched in Overdrive" : "not on this machine")
                        : guard.on ? "ON" : guard.available ? "clear" : "not on this machine"
                    technical: true
                    font.capitalization: Font.MixedCase
                    color: guard.on ? Design.warm : Design.faint
                }
            }
        }
        FText { text: "TIERS"; technical: true; color: Design.faint; Layout.topMargin: 4 }
        Repeater {
            model: [
                { tier: "T1", name: "Panel", note: "every effect inside this panel", on: true },
                { tier: "T2", name: "Clock and satellites", note: "M16", on: false },
                { tier: "T3", name: "Desktop layer", note: "M16", on: false }
            ]
            RowLayout {
                required property var modelData
                Layout.fillWidth: true
                spacing: 8
                FText { text: modelData.tier; technical: true; color: modelData.on && root.lease.active ? Design.accent : Design.faint }
                FText { text: modelData.name; color: modelData.on ? Design.ink : Design.faint; Layout.fillWidth: true }
                FText { text: modelData.note; technical: true; font.capitalization: Font.MixedCase; color: Design.faint }
            }
        }
        FText { text: "ENGINE"; technical: true; color: Design.faint; Layout.topMargin: 4 }
        FText {
            Layout.fillWidth: true
            text: "drive " + Math.round(Motion.drive * 100) + " %  ·  loops " + Motion.idleLoops + "  ·  " + root.fps + " frames/s"
                + (root.heat && root.heat.running ? "  ·  CPU " + root.heat.cpu.toFixed(1) + " % of a core" : "")
            technical: true
            font.capitalization: Font.MixedCase
            color: Design.muted
        }
        FText {
            Layout.fillWidth: true
            visible: root.lease.heard !== null
            text: root.lease.heard ? "heard: " + root.lease.heardNames[root.lease.heard.cue] + "  ·  " + root.ago(root.lease.heard.at) : ""
            technical: true
            font.capitalization: Font.MixedCase
            color: Design.muted
        }
        FText {
            Layout.fillWidth: true
            text: Strata.count === 0 ? "no strata exist" : "strata: " + Strata.live.join(", ")
            technical: true
            font.capitalization: Font.MixedCase
            wrapMode: Text.Wrap
            color: Design.muted
        }
    }
}
