import QtQuick
import QtQuick.Shapes

// Z64 and Z145. The island's silhouette: one matte fill, no rim, sheen or bevel (Z151). Draw once when the
// dimensions, edge, form or palette change.
//   Angular: 84° shoulders from the flat edge, `shoulderDepth` deep, then straight sides.
//   Fluid:   straight sides with rounded corners away from the edge, flared into the edge by concave curves.
Item {
    id: root
    property bool bottomEdge: false
    property bool fluid: Design.fluid
    // How deep the 84° shoulders run from the flat edge; below that the sides are straight. The island is all
    // shoulder; the panel grown from it keeps the island's bar depth as its shoulders and drops straight below.
    property real shoulderDepth: height
    // Fluid: the radius of the two corners away from the screen edge.
    property real corner: Design.roundIsland
    // The matte fill; a critical event's flash (Z161) draws a second frame in Design.danger over it.
    property color fill: Design.islandFill
    implicitWidth: 420
    implicitHeight: 36

    readonly property real shoulderSlope: 1 / Math.tan(84 * Math.PI / 180)
    readonly property real kneeDepth: Math.min(height, shoulderDepth)
    readonly property real shoulderRun: fluid ? 0 : kneeDepth * shoulderSlope

    // Fluid path, measured from the screen edge (mirrored for the bottom edge): the flare, the far corners'
    // radius, and the turn of each arc (the path runs down the left side and back along the edge).
    readonly property real ear: fluid ? Math.max(0, Math.min(Design.roundEar, (width - 2) / 4, height / 2)) : 0
    readonly property real radius: Math.max(0, Math.min(corner, (width - 2 * ear) / 2, height - ear))
    readonly property real y0: bottomEdge ? height : 0
    function edgeY(depth: real): real { return bottomEdge ? height - depth : depth; }
    readonly property int concave: bottomEdge ? PathArc.Counterclockwise : PathArc.Clockwise
    readonly property int convex: bottomEdge ? PathArc.Clockwise : PathArc.Counterclockwise

    function vertex(x: real, y: real): point {
        return Qt.point(x, bottomEdge ? height - y : y);
    }

    Shape {
        anchors.fill: parent
        visible: !root.fluid
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: root.fill
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

    // Fluid: flush with the edge, rounded away from it, and flared into the edge by a concave curve each side.
    // The flares sit inside the frame's width, so the body runs `ear` in from either side.
    Shape {
        anchors.fill: parent
        visible: root.fluid
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: root.fill
            strokeWidth: -1
            startX: 0; startY: root.y0
            PathArc { x: root.ear; y: root.edgeY(root.ear); radiusX: root.ear; radiusY: root.ear; direction: root.concave }
            PathLine { x: root.ear; y: root.edgeY(root.height - root.radius) }
            PathArc { x: root.ear + root.radius; y: root.edgeY(root.height); radiusX: root.radius; radiusY: root.radius; direction: root.convex }
            PathLine { x: root.width - root.ear - root.radius; y: root.edgeY(root.height) }
            PathArc { x: root.width - root.ear; y: root.edgeY(root.height - root.radius); radiusX: root.radius; radiusY: root.radius; direction: root.convex }
            PathLine { x: root.width - root.ear; y: root.edgeY(root.ear) }
            PathArc { x: root.width; y: root.y0; radiusX: root.ear; radiusY: root.ear; direction: root.concave }
            PathLine { x: 0; y: root.y0 }
        }
    }
}
