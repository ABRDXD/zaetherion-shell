import QtQuick
import QtQuick.Shapes

// Geometry only: callers own palette, interaction and the geometric/round switch.
// An Item wrapper keeps Shape bounds out of a control's implicit-size calculation.
Item {
    id: root
    implicitWidth: 0
    implicitHeight: 0
    property bool chamfered: true
    property real radius: 8
    property real cutSize: 4
    property color fillColor: "transparent"
    property color lineColor: "transparent"
    property real lineWidth: 1
    readonly property real cut: Math.max(0, Math.min(cutSize, width / 3, height / 3))
    Rectangle {
        anchors.fill: parent
        visible: !root.chamfered
        radius: Math.min(root.radius, width / 2, height / 2)
        color: root.fillColor
        border.width: root.lineWidth
        border.color: root.lineColor
    }
    Shape {
        anchors.fill: parent
        visible: root.chamfered
        antialiasing: true
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeWidth: root.lineWidth
            strokeColor: root.lineColor
            fillColor: root.fillColor
            startX: root.cut + 0.5
            startY: 0.5
            PathLine { x: root.width - root.cut - 0.5; y: 0.5 }
            PathLine { x: root.width - 0.5; y: root.cut + 0.5 }
            PathLine { x: root.width - 0.5; y: root.height - root.cut - 0.5 }
            PathLine { x: root.width - root.cut - 0.5; y: root.height - 0.5 }
            PathLine { x: root.cut + 0.5; y: root.height - 0.5 }
            PathLine { x: 0.5; y: root.height - root.cut - 0.5 }
            PathLine { x: 0.5; y: root.cut + 0.5 }
            PathLine { x: root.cut + 0.5; y: 0.5 }
        }
    }
}
