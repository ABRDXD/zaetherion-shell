import QtQuick
import QtQuick.Shapes

// A small cold star (Z199): a blue-white core fading into a short glow. Centred on (0, 0) of its parent's coordinate
// at x, y: set `radius` and place it with x/y as its centre.
Shape {
    id: root
    property real radius: 24
    x: -radius
    y: -radius
    width: 2 * radius
    height: 2 * radius
    preferredRendererType: Shape.CurveRenderer
    ShapePath {
        strokeColor: "transparent"
        fillGradient: RadialGradient {
            centerX: root.radius; centerY: root.radius; focalX: root.radius; focalY: root.radius
            centerRadius: root.radius; focalRadius: 0
            GradientStop { position: 0; color: Design.coldCore }
            GradientStop { position: 0.34; color: Design.coldStar }
            GradientStop { position: 0.52; color: Qt.alpha(Design.coldStar, 0.28) }
            GradientStop { position: 0.7; color: Qt.alpha(Design.coldStar, 0) }
        }
        PathAngleArc { centerX: root.radius; centerY: root.radius; radiusX: root.radius; radiusY: root.radius; startAngle: 0; sweepAngle: 360 }
    }
}
