import qs.view.cues
import qs.view.ui
import QtQuick

// The lease in the header (D16 "lease shown in the panel", docs/OVERDRIVE.md §1): a five-bar tachometer that
// lights with the engine (Motion.drive) and the state in words. SILENT, OVERDRIVE · PANEL / STICKY / 19:42 left,
// SUSPENDED · <guard>, or REDUCED MOTION when the lease is held but motion is off. A click opens the lease
// manager. A timed lease's countdown ticks once a second only while it is shown.
Item {
    id: root
    required property OverdriveLease lease
    property bool open: false
    signal toggled()
    implicitWidth: row.implicitWidth + 12
    implicitHeight: 24
    property double now: Date.now()
    Timer {
        interval: 1000
        repeat: true
        running: root.lease.mode === "timed" && root.visible
        triggeredOnStart: true
        onTriggered: root.now = Date.now()
    }
    function clock(ms) {
        const s = Math.max(0, Math.round(ms / 1000));
        const h = Math.floor(s / 3600), m = Math.floor(s % 3600 / 60), sec = s % 60;
        const pad = n => (n < 10 ? "0" : "") + n;
        return h > 0 ? h + ":" + pad(m) + ":" + pad(sec) : pad(m) + ":" + pad(sec);
    }
    readonly property string state: !lease.requested ? (Motion.driving ? "OVERDRIVE" : Motion.drive > 0 ? "SPINNING DOWN" : "SILENT")
        : Motion.reduced ? "OVERDRIVE · REDUCED MOTION"
        : lease.suspended ? "SUSPENDED · " + lease.reason().toUpperCase()
        : "OVERDRIVE · " + (lease.mode === "timed" ? clock((lease.until ?? now) - now) : lease.mode.toUpperCase())
    readonly property color tone: !lease.requested ? (Motion.driving ? Design.accent : Design.faint) : lease.suspended || Motion.reduced ? Design.warm : Design.accent
    Accessible.role: Accessible.Button
    Accessible.name: "Overdrive: " + state
    Rectangle {
        anchors.fill: parent
        color: root.open ? Qt.alpha(root.tone, 0.16) : mouse.containsMouse ? Design.hover : "transparent"
        border.width: root.lease.requested ? 1 : 0
        border.color: Qt.alpha(root.tone, 0.6)
    }
    Row {
        id: row
        x: 6
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8
        // The tachometer: bars lean at 78° and light from left to right as the engine spins up.
        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            Repeater {
                model: 5
                Rectangle {
                    required property int index
                    readonly property bool lit: Motion.drive > (index + 0.5) / 5
                    width: 3
                    height: 6 + index * 2
                    anchors.bottom: parent.bottom
                    color: lit ? (index === 4 ? Design.warm : root.tone) : Qt.alpha(Design.line, 0.8)
                    transform: Matrix4x4 { matrix: Qt.matrix4x4(1, Design.shear, 0, -Design.shear * height, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1) }
                }
            }
        }
        FText {
            anchors.verticalCenter: parent.verticalCenter
            text: root.state
            technical: true
            font.pixelSize: Design.caption
            font.letterSpacing: 1.5
            color: root.tone
        }
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }
}
