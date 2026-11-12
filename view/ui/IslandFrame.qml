import QtQuick
import QtQuick.Shapes

// Z64 and Z144. Draw once when the dimensions, edge or palette change.
// The light is fixed, from the left: a lit rim on the outline, a faint upper face and a 4 px lower facet.
Item {
    id: root
    property bool bottomEdge: false
    // An alarm tints the rim with the signal role; the fill never changes.
    property bool alarm: false
    implicitWidth: 420
    implicitHeight: 36

    readonly property real shoulderSlope: 1 / Math.tan(84 * Math.PI / 180)
    readonly property real shoulderRun: height * shoulderSlope
    readonly property real bevelDepth: 4
    readonly property real bevelRun: (height - bevelDepth) * shoulderSlope
    readonly property color rim: alarm ? Design.accent : Design.ink

    function vertex(x: real, y: real): point {
        return Qt.point(x, bottomEdge ? height - y : y);
    }
    readonly property var outline: [vertex(0, 0), vertex(width, 0), vertex(width - shoulderRun, height),
                                    vertex(shoulderRun, height), vertex(0, 0)]

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: Design.islandFill
            strokeWidth: -1
            PathPolyline { path: root.outline }
        }

        // Upper face: the first 10 px of depth catch a little of the light.
        ShapePath {
            strokeWidth: -1
            fillGradient: LinearGradient {
                x1: 0; y1: root.bottomEdge ? root.height : 0
                x2: 0; y2: root.bottomEdge ? 0 : root.height
                GradientStop { position: 0; color: Qt.alpha(Design.ink, 0.065) }
                GradientStop { position: Math.min(1, 10 / Math.max(1, root.height)); color: Qt.alpha(Design.ink, 0) }
            }
            PathPolyline { path: root.outline }
        }

        // Lower facet.
        ShapePath {
            strokeWidth: -1
            fillGradient: LinearGradient {
                x1: 0; y1: root.bottomEdge ? root.bevelDepth : root.height - root.bevelDepth
                x2: 0; y2: root.bottomEdge ? 0 : root.height
                GradientStop { position: 0; color: Qt.alpha(Design.ink, 0.22) }
                GradientStop { position: 1; color: Qt.alpha(Design.ink, 0.05) }
            }
            PathPolyline {
                path: [root.vertex(root.bevelRun, root.height - root.bevelDepth),
                       root.vertex(root.width - root.bevelRun, root.height - root.bevelDepth),
                       root.vertex(root.width - root.shoulderRun, root.height),
                       root.vertex(root.shoulderRun, root.height),
                       root.vertex(root.bevelRun, root.height - root.bevelDepth)]
            }
        }

        // Lit rim on the open outline, brightest at the left shoulder.
        ShapePath {
            fillColor: "transparent"
            strokeWidth: 1
            capStyle: ShapePath.FlatCap
            joinStyle: ShapePath.MiterJoin
            strokeGradient: LinearGradient {
                x1: 0; y1: 0
                x2: root.width; y2: 0
                GradientStop { position: 0; color: Qt.alpha(root.rim, root.alarm ? 0.7 : 0.36) }
                GradientStop { position: 0.72; color: Qt.alpha(root.rim, root.alarm ? 0.3 : 0.12) }
                GradientStop { position: 1; color: Qt.alpha(root.rim, 0.04) }
            }
            PathPolyline {
                path: [root.vertex(root.shoulderRun + 0.5, root.height - 0.5), root.vertex(0.5, 0.5),
                       root.vertex(root.width - 0.5, 0.5),
                       root.vertex(root.width - root.shoulderRun - 0.5, root.height - 0.5)]
            }
        }
    }
}
