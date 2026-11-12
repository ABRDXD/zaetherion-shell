import QtQuick
import QtQuick.Shapes

// Z64. The island's silhouette: one matte fill, no rim, sheen or bevel (owner, 12 November 2026: matte and modern,
// not glossy). Draw once when the dimensions, edge or palette change.
Item {
    id: root
    property bool bottomEdge: false
    // How deep the 84° shoulders run from the flat edge; below that the sides are straight. The island is all
    // shoulder; the panel grown from it keeps the island's bar depth as its shoulders and drops straight below.
    property real shoulderDepth: height
    implicitWidth: 420
    implicitHeight: 36

    readonly property real shoulderSlope: 1 / Math.tan(84 * Math.PI / 180)
    readonly property real kneeDepth: Math.min(height, shoulderDepth)
    readonly property real shoulderRun: kneeDepth * shoulderSlope

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
                       root.vertex(root.width - root.shoulderRun, root.kneeDepth),
                       root.vertex(root.width - root.shoulderRun, root.height),
                       root.vertex(root.shoulderRun, root.height),
                       root.vertex(root.shoulderRun, root.kneeDepth), root.vertex(0, 0)]
            }
        }
    }
}
