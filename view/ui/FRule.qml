import QtQuick
import QtQuick.Shapes

// One continuous 1px rule with a diagonal registration notch.
Item {
    id: root
    implicitHeight: 5
    property color color: Design.line
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: root.color
            strokeWidth: 1
            fillColor: "transparent"
            startX: 0; startY: 4
            PathLine { x: Math.max(0, root.width - 42); y: 4 }
            PathLine { x: Math.max(0, root.width - 34); y: 0 }
            PathLine { x: root.width; y: 0 }
        }
    }
}
