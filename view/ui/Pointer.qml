import QtQuick
import QtQuick.Shapes

// The sheet's pointer (MONTAGE.md §4.4): a small solid arrowhead whose back edge leans at 78°, set beside
// the chosen row of a list. Static geometry; owners move or hide it.
Item {
    id: root
    property color color: Design.ink
    implicitWidth: 9
    implicitHeight: 12
    readonly property real run: height * Math.tan(12 * Math.PI / 180)
    Shape {
        anchors.fill: parent
        antialiasing: true
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: "transparent"
            fillColor: root.color
            PathPolyline {
                path: [Qt.point(root.run, 0), Qt.point(root.width, root.height / 2), Qt.point(0, root.height),
                    Qt.point(root.run / 2 + root.width * 0.2, root.height / 2), Qt.point(root.run, 0)]
            }
        }
    }
}
