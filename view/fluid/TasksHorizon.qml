import QtQuick
import QtQuick.Shapes
import qs.view.cues
import qs.view.ui

// The planet under Fluid Tasks (owner's pick "Planet horizon", 15 November 2026): a vast planet's edge rises along the
// bottom of the room, lit from behind. Its air glows warm while anything is late and cold blue while on track. A ring
// above the limb fills as the day's tasks are done, and the light behind the planet brightens with it, a slow sunrise.
Item {
    id: root
    property real progress: 0      // done today / (done today + open), 0–1
    property bool late: false
    property int done: 0
    property int total: 0
    readonly property real planetR: width * 1.6
    readonly property real limbY: height * 0.84          // the limb's highest point
    readonly property real cx: width / 2
    readonly property real cy: limbY + planetR
    property color air: late ? Design.warm : Design.atmosphere
    Tween on air { scope: root; ColorAnimation { duration: Motion.scaled(1200) } }
    property real shown: progress
    Tween on shown { scope: root; NumberAnimation { duration: Motion.scaled(1100); easing.type: Easing.OutCubic } }

    // The light behind the planet: wide and faint, brighter as the day's work is done.
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: "transparent"
            fillGradient: RadialGradient {
                centerX: root.cx; centerY: root.limbY; focalX: centerX; focalY: centerY
                centerRadius: root.width * (0.35 + 0.25 * root.shown); focalRadius: 0
                GradientStop { position: 0; color: Qt.alpha(root.air, 0.22 + 0.3 * root.shown) }
                GradientStop { position: 0.35; color: Qt.alpha(root.air, 0.07 + 0.08 * root.shown) }
                GradientStop { position: 1; color: "transparent" }
            }
            PathRectangle { x: 0; y: 0; width: root.width; height: root.height }
        }
    }
    // The ring above the limb: a faint track, filled left to right with what is done today.
    Shape {
        id: ring
        objectName: "tasksRing"
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        readonly property real rr: root.planetR + root.height * 0.05
        readonly property real span: 2 * Math.asin(Math.min(1, root.width * 0.46 / rr)) * 180 / Math.PI   // degrees visible
        ShapePath {
            strokeColor: Qt.alpha(Design.coldRim, 0.18)
            strokeWidth: 1
            fillColor: "transparent"
            PathAngleArc { centerX: root.cx; centerY: root.cy; radiusX: ring.rr; radiusY: ring.rr; startAngle: 270 - ring.span / 2; sweepAngle: ring.span }
        }
        ShapePath {
            strokeColor: Qt.alpha(Design.coldCore, 0.85)
            strokeWidth: 2.5
            capStyle: ShapePath.RoundCap
            fillColor: "transparent"
            PathAngleArc { centerX: root.cx; centerY: root.cy; radiusX: ring.rr; radiusY: ring.rr; startAngle: 270 - ring.span / 2; sweepAngle: Math.max(0.01, ring.span * root.shown) }
        }
    }
    FText {
        objectName: "tasksRingLabel"
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.limbY - root.height * 0.05 - height - Design.baseline * 2
        technical: true
        font.pixelSize: Design.caption
        color: Design.coldInk
        text: root.total === 0 ? "NOTHING ON TODAY'S RING" : root.done + " OF " + root.total + " DONE TODAY"
    }
    // The planet: its dark body, the thin air along the limb, and the lit edge itself.
    Shape {
        objectName: "tasksPlanet"
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: Qt.alpha(root.air, 0.08)
            strokeWidth: root.height * 0.05
            fillColor: "transparent"
            PathAngleArc { centerX: root.cx; centerY: root.cy; radiusX: root.planetR + root.height * 0.012; radiusY: root.planetR + root.height * 0.012; startAngle: 180; sweepAngle: 180 }
        }
        ShapePath {
            strokeColor: Qt.alpha(root.air, 0.9)
            strokeWidth: 1.5
            fillGradient: LinearGradient {
                x1: 0; y1: root.limbY; x2: 0; y2: root.height
                GradientStop { position: 0; color: Qt.alpha(root.air, 0.10) }
                GradientStop { position: 0.12; color: Design.coldBody }
                GradientStop { position: 1; color: Design.voidFill }
            }
            PathAngleArc { centerX: root.cx; centerY: root.cy; radiusX: root.planetR; radiusY: root.planetR; startAngle: 0; sweepAngle: 360 }
        }
    }
    // The point of light just behind the limb, the sunrise.
    Rectangle {
        readonly property real d: 4 + 6 * root.shown
        x: root.cx - d / 2; y: root.limbY - d / 2; width: d; height: d; radius: d / 2
        color: Design.coldCore
        opacity: 0.6 + 0.4 * root.shown
    }
}
