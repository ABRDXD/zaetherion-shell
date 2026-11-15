import QtQuick
import QtQuick.Shapes
import qs.view.cues
import qs.view.ui
import "LauncherLayout.js" as Layout

// What stands at the orbit's barycentre for the pick's kind (Z196), so a lone result never leaves an empty chart:
// a sum is a binary pair (what you typed and its answer) spun up once around the centre; `?term` a nebula; a FART
// verb a pulsar whose beams sweep once and settle at −12°; `>cmd` a comet that streaks in along the 78° slope.
// An app has no scenery: the ring of results is the picture. `revealed` (0–1) runs once per new pick; at rest it is 1.
Item {
    id: root
    property string kind: ""
    property color tint: Design.ink
    property string typed: ""    // a sum: what was typed
    property string answer: ""   // a sum: the answer
    property real revealed: 1
    readonly property real cx: Layout.orbitX
    readonly property real cy: Layout.orbitY

    // Binary: two stars on a tight tilted orbit about the barycentre, a half turn on reveal.
    Item {
        visible: root.kind === "calc" || root.kind === "convert"
        x: root.cx
        y: root.cy
        Shape {
            x: -Layout.sceneryRx; y: -Layout.sceneryRy; width: 2 * Layout.sceneryRx; height: 2 * Layout.sceneryRy
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: Qt.alpha(root.tint, 0.5)
                strokeStyle: ShapePath.DashLine
                dashPattern: [3, 5]
                fillColor: "transparent"
                PathAngleArc { centerX: Layout.sceneryRx; centerY: Layout.sceneryRy; radiusX: Layout.sceneryRx; radiusY: Layout.sceneryRy; startAngle: 0; sweepAngle: 360 }
            }
        }
        Repeater {
            model: 2
            delegate: Item {
                required property int index
                readonly property real angle: Math.PI * (index + root.revealed)  // what you typed ends on the left
                x: Layout.sceneryRx * Math.cos(angle)
                y: Layout.sceneryRy * Math.sin(angle)
                z: Math.sin(angle)
                Rectangle {
                    readonly property real d: index ? Layout.binaryStar * 1.2 : Layout.binaryStar
                    x: -d / 2; y: -d / 2; width: d; height: d; radius: d / 2
                    color: index ? Design.spectral[0] : Design.binary
                    border.width: 2
                    border.color: Qt.alpha(Design.ink, 0.5)
                }
                FText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: Layout.binaryStar
                    headline: true
                    font.capitalization: Font.MixedCase
                    font.pixelSize: Design.readout
                    font.weight: Font.Black
                    color: index ? Design.spectral[0] : Design.binary
                    text: index ? root.answer : root.typed
                }
            }
        }
    }

    // Nebula: overlapping soft clouds, opening out on reveal.
    Repeater {
        model: root.kind === "search" ? Layout.nebula : []
        delegate: Shape {
            required property var modelData
            required property int index
            // Alternate clouds glow in the pulsar's violet, so the nebula has depth of colour.
            readonly property color glow: index % 2 ? Design.pulsar : root.tint
            readonly property real r: modelData[2] * (0.6 + 0.4 * root.revealed)
            id: cloud
            x: root.cx + modelData[0] - r
            y: root.cy + modelData[1] - r
            width: 2 * r
            height: 2 * r
            opacity: root.revealed
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: "transparent"
                fillGradient: RadialGradient {
                    centerX: cloud.r; centerY: cloud.r; focalX: cloud.r; focalY: cloud.r; centerRadius: cloud.r; focalRadius: 0
                    GradientStop { position: 0; color: Qt.alpha(cloud.glow, 0.5) }
                    GradientStop { position: 0.5; color: Qt.alpha(cloud.glow, 0.16) }
                    GradientStop { position: 1; color: Qt.alpha(cloud.glow, 0) }
                }
                PathAngleArc { centerX: cloud.r; centerY: cloud.r; radiusX: cloud.r; radiusY: cloud.r; startAngle: 0; sweepAngle: 360 }
            }
        }
    }

    // Pulsar: a bright core and two opposed beams that sweep a half turn and settle on the −12° lean.
    Item {
        visible: root.kind === "verb"
        x: root.cx
        y: root.cy
        rotation: -12 + 180 * (1 - root.revealed)
        Repeater {
            model: 2
            delegate: Rectangle {
                required property int index
                width: Layout.beam
                height: 3
                x: index ? 0 : -width
                y: -1.5
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: index ? root.tint : "transparent" }
                    GradientStop { position: 1; color: index ? "transparent" : root.tint }
                }
            }
        }
        Rectangle {
            x: -width / 2; y: -height / 2; width: Layout.binaryStar; height: width; radius: width / 2
            color: root.tint
        }
    }

    // Comet: a nucleus with its tail, streaking in along the 78° slope from the top left to the barycentre.
    Item {
        visible: root.kind === "command"
        x: root.cx - (1 - root.revealed) * Layout.beam
        y: root.cy + (1 - root.revealed) * Layout.beam * Design.shear
        rotation: 180 + 12  // the tail trails back up the −12° line it came in on
        Rectangle {
            width: Layout.beam
            height: 3
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: root.tint }
                GradientStop { position: 1; color: "transparent" }
            }
            y: -1.5
        }
        Rectangle {
            x: -width / 2; y: -height / 2; width: Layout.binaryStar; height: width; radius: width / 2
            color: root.tint
        }
    }
}
