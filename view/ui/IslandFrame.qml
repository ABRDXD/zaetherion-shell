import QtQuick
import QtQuick.Shapes

// Z64 and Z144. Draw once when the dimensions, edge or palette change.
Item {
    id: root
    property bool bottomEdge: false
    implicitWidth: 420
    implicitHeight: 36

    readonly property real shoulderSlope: 1 / Math.tan(84 * Math.PI / 180)
    readonly property real shoulderRun: height * shoulderSlope
    readonly property real bevelDepth: 4
    readonly property real bevelRun: (height - bevelDepth) * shoulderSlope

    function vertex(x: real, y: real): point {
        return Qt.point(x, bottomEdge ? height - y : y);
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: Design.islandFill
            strokeWidth: -1
            PathPolyline {
                path: [root.vertex(0, 0), root.vertex(root.width, 0),
                       root.vertex(root.width - root.shoulderRun, root.height),
                       root.vertex(root.shoulderRun, root.height), root.vertex(0, 0)]
            }
        }

        ShapePath {
            fillColor: Qt.alpha(Design.ink, 0.10)
            strokeWidth: -1
            PathPolyline {
                path: [root.vertex(root.bevelRun, root.height - root.bevelDepth),
                       root.vertex(root.width - root.bevelRun, root.height - root.bevelDepth),
                       root.vertex(root.width - root.shoulderRun, root.height),
                       root.vertex(root.shoulderRun, root.height),
                       root.vertex(root.bevelRun, root.height - root.bevelDepth)]
            }
        }

        ShapePath {
            fillColor: "transparent"
            strokeColor: Qt.alpha(Design.ink, 0.22)
            strokeWidth: 1
            capStyle: ShapePath.FlatCap
            PathPolyline {
                path: [root.vertex(root.shoulderRun, root.height - 0.5),
                       root.vertex(0.5, 0.5), root.vertex(root.width - 0.5, 0.5)]
            }
        }
    }
}
