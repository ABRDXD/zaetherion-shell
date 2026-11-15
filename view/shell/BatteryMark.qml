import qs.view.ui
import QtQuick

// The battery in the panel's header (the user, 9 November): a cell leaning at the house angle, filled to the charge, with the percentage beside it. In both modes, and it never moves
// on its own. Desktops have no battery, so nothing shows there.
Row {
    id: root
    required property var battery
    property bool showPercentage: true
    property bool signalOnly: false
    // Fluid: upright with rounded corners instead of the −12° cell.
    property bool rounded: false
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
        transform: Matrix4x4 { matrix: Qt.matrix4x4(1, root.rounded ? 0 : Design.shear, 0, root.rounded ? 0 : -Design.shear * 13 / 2, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1) }
        Rectangle {
            id: cell
            width: parent.width - 3
            height: parent.height
            color: "transparent"
            radius: root.rounded ? 4 : 0
            border.width: root.rounded ? 1.5 : 1
            border.color: root.tone
        }
        Rectangle {
            x: root.rounded ? 2.5 : 2
            y: root.rounded ? 2.5 : 2
            width: Math.max(0, (cell.width - (root.rounded ? 5 : 4)) * root.level)
            height: cell.height - (root.rounded ? 5 : 4)
            radius: root.rounded ? 2 : 0
            color: root.tone
        }
        Rectangle {
            x: cell.width + (root.rounded ? 0.5 : 0)
            y: 4
            width: root.rounded ? 2.5 : 3
            height: parent.height - 8
            radius: root.rounded ? 1.25 : 0
            color: root.tone
        }
    }
    // The percentage rolls as it changes (RollingDigits, after NumberFlow), in FText's technical voice.
    RollingDigits {
        objectName: "batteryPercent"
        visible: root.showPercentage
        anchors.verticalCenter: parent.verticalCenter
        text: Math.round(root.level * 100) + "%" + (root.battery.charging ? " ↑" : "")
        font.family: Design.mono
        font.pixelSize: Design.caption
        font.letterSpacing: 0.7
        font.capitalization: Font.AllUppercase
        font.features: ({ "tnum": 1 })
        color: root.tone
    }
}
