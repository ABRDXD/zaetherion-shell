import qs.view.ui
import QtQuick

// The battery in the panel's header (the user, 9 November): a cell leaning at the house angle, filled to the charge, with the percentage beside it. In both modes, and it never moves
// on its own. Desktops have no battery, so nothing shows there.
Row {
    id: root
    required property var battery
    property bool showPercentage: true
    property bool signalOnly: false
    readonly property real level: Math.max(0, Math.min(1, battery.level ?? 0))
    readonly property bool draining: !!battery.available && !battery.pluggedIn
    // The same thresholds as the footer's power readout.
    readonly property color tone: signalOnly ? (draining && level <= 0.2 || battery.charging ? Design.accent : Design.ink)
        : draining && level <= 0.1 ? Design.danger : draining && level <= 0.2 ? Design.warning : battery.charging ? Design.accent : Design.ink
    visible: !!battery.available
    spacing: 7
    Accessible.role: Accessible.StaticText
    Accessible.name: "Battery " + Math.round(level * 100) + " percent" + (battery.charging ? ", charging" : battery.pluggedIn ? ", plugged in" : "")
    Item {
        anchors.verticalCenter: parent.verticalCenter
        width: 30
        height: 13
        transform: Matrix4x4 { matrix: Qt.matrix4x4(1, Design.shear, 0, -Design.shear * 13 / 2, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1) }
        Rectangle {
            id: cell
            width: parent.width - 3
            height: parent.height
            color: "transparent"
            border.width: 1
            border.color: root.tone
        }
        Rectangle {
            x: 2
            y: 2
            width: (cell.width - 4) * root.level
            height: cell.height - 4
            color: root.tone
        }
        Rectangle {
            x: cell.width
            y: 4
            width: 3
            height: parent.height - 8
            color: root.tone
        }
    }
    FText {
        visible: root.showPercentage
        anchors.verticalCenter: parent.verticalCenter
        text: Math.round(root.level * 100) + "%" + (root.battery.charging ? " ↑" : "")
        technical: true
        font.pixelSize: Design.caption
        color: root.tone
    }
}
