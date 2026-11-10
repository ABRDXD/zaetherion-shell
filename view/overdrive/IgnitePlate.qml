import qs.view.cues
import qs.view.ui
import QtQuick

// The ignite plate (D16, docs/OVERDRIVE.md §2): FART's logo is the ignition key. Hold it 600 ms to ignite
// Overdrive for this panel; hold it again to cut it. The core times the hold (the same machine as Super+`), so a
// tap does nothing and the release always ends the meter. The logo heats towards the signal colour as the
// hold burns, and in Overdrive it stays lit with the engine (Motion.drive).
Item {
    id: root
    required property OverdriveLease lease
    implicitWidth: logo.implicitWidth
    implicitHeight: logo.implicitHeight
    readonly property real heat: lease.holding ? Math.min(1, (fuseNow - lease.holdSince) / 600) : 0
    // The fuse shares the frame clock while held; the plate only reads it.
    property double fuseNow: 0
    readonly property real glow: Math.max(heat, Motion.drive)
    readonly property color hot: lease.requested && lease.holding ? Design.warm : Design.accent
    Accessible.role: Accessible.Button
    Accessible.name: lease.requested ? "Hold to cut Overdrive" : "Hold to ignite Overdrive"
    FText {
        id: logo
        text: "F/"
        headline: true
        font.pixelSize: Design.figure
        font.weight: Font.Black
        color: Qt.tint(Design.ink, Qt.alpha(root.hot, root.glow))
        transform: Scale {
            origin.x: logo.width / 2
            origin.y: logo.height / 2
            xScale: 1 + 0.08 * root.heat
            yScale: 1 + 0.08 * root.heat
        }
    }
    // The hint, under the logo while the pointer is over it.
    FText {
        anchors.top: logo.bottom
        anchors.topMargin: -4
        anchors.horizontalCenter: logo.horizontalCenter
        visible: mouse.containsMouse && !root.lease.holding
        text: root.lease.requested ? "HOLD · CUT" : "HOLD · IGNITE"
        technical: true
        font.pixelSize: Design.caption
        font.letterSpacing: 1.5
        color: root.hot
        z: 40
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        anchors.margins: -4
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onPressed: root.lease.holdDown()
        onReleased: root.lease.holdUp()
        onCanceled: root.lease.holdUp()
    }
}
