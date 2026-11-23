import QtQuick

// A level, static between changes. Angular: a row of −12° blades, signal up to the level and faint ink after it.
// Fluid: one rounded track with a rounded signal fill.
Item {
    id: root
    property real level: 0
    property bool muted: false
    property int blades: 24
    readonly property real clamped: Math.max(0, Math.min(1, level))
    implicitHeight: Design.baseline * 2
    height: implicitHeight

    Row {
        anchors.fill: parent
        visible: !Design.fluid
        spacing: 3
        Repeater {
            model: Design.fluid ? 0 : root.blades
            Plane {
                required property int index
                width: Math.max(1, (root.width - 3 * (root.blades - 1)) / root.blades)
                height: root.height
                role: !root.muted && (index + 1) / root.blades <= root.clamped + 1e-6 ? "signal" : "ink"
                opacity: role === "signal" ? 1 : 0.22
                slant: 3
            }
        }
    }
    Rectangle {
        anchors.fill: parent
        visible: Design.fluid
        radius: height / 2
        color: Qt.alpha(Design.ink, 0.22)
        Rectangle {
            width: root.muted ? 0 : Math.max(parent.height, parent.width * root.clamped)
            visible: !root.muted && root.clamped > 0
            height: parent.height
            radius: height / 2
            color: Design.accent
        }
    }
}
