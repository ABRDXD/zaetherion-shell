import QtQuick
import QtQuick.Shapes
import qs.view.cues
import qs.view.ui
import "TimersSkyLayout.js" as Sky

// The Fluid Timers sky (owner's pick "B + C", 15 November 2026): you stand on a planet whose vast curved horizon fills
// the bottom of the room. A black hole crosses its sky over a stretch, rise to set, its tilted disc lighting the thin
// air. The time still to go is bright matter on an inward spiral around it; one pulsing light, now, falls inward as
// the stretch runs. `lit` false (rest, or nothing set) darkens the disc and brings the stars out. The light breathes
// only while `running`; held, the scene is still.
Item {
    id: root
    property real progress: 0     // 0 rise / at the rim … 1 set / fallen in
    // Where the hole stands on its path (0 rise … 1 set); by default it follows the progress. A clock with no deadline
    // (the stopwatch) holds it at the top while the light alone falls.
    property real arc: progress
    property bool lit: false
    property bool running: false
    readonly property var hole: Sky.holeAt(lit ? arc : 1, width, height)
    readonly property real high: lit ? Math.sin(Math.PI * arc) : 0   // how high the hole stands
    readonly property real u: lit ? progress : 1
    clip: true

    // The sky: dark, warmed toward the hole by its glow while it stands high.
    Shape {
        anchors.fill: parent
        ShapePath {
            strokeColor: "transparent"
            fillGradient: RadialGradient {
                centerX: root.hole.x; centerY: root.hole.y; focalX: centerX; focalY: centerY
                centerRadius: Math.max(root.width, root.height) * 0.62; focalRadius: 0
                GradientStop { position: 0; color: Qt.alpha(Design.atmosphere, 0.10 + 0.14 * root.high) }
                GradientStop { position: 0.45; color: Qt.alpha(Design.coldLine, 0.45 * root.high) }
                GradientStop { position: 1; color: Design.voidFill }
            }
            PathRectangle { x: 0; y: 0; width: root.width; height: root.height }
        }
    }
    // Stars, fixed; brighter when the disc is dark.
    Repeater {
        model: Sky.stars
        Rectangle {
            required property var modelData
            x: modelData[0] * root.width
            y: modelData[1] * root.height
            width: modelData[2]
            height: width
            radius: width / 2
            color: Design.coldStar
            opacity: root.lit ? 0.35 + 0.4 * (1 - root.high) : 1
        }
    }
    // The hole's path, a faint dotted arc.
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: Qt.alpha(Design.coldLine, 0.9)
            strokeWidth: 1
            strokeStyle: ShapePath.DashLine
            dashPattern: [2, 7]
            fillColor: "transparent"
            startX: Sky.riseX * root.width; startY: Sky.riseY * root.height
            PathQuad { controlX: Sky.apexX * root.width; controlY: Sky.apexY * root.height; x: Sky.setX * root.width; y: Sky.setY * root.height }
        }
    }

    // The hole, its disc, the spiral of time and the light.
    Item {
        id: hole
        objectName: "timers.hole"
        x: root.hole.x
        y: root.hole.y
        opacity: root.lit ? 1 : 0.25
        // A broad glow around it.
        Shape {
            readonly property real r: Sky.glowRadius
            x: -r; y: -r; width: 2 * r; height: 2 * r
            ShapePath {
                strokeColor: "transparent"
                fillGradient: RadialGradient {
                    centerX: Sky.glowRadius; centerY: Sky.glowRadius; focalX: centerX; focalY: centerY; centerRadius: Sky.glowRadius; focalRadius: 0
                    GradientStop { position: 0; color: Qt.alpha(Design.coldRim, 0.12 + 0.2 * root.high) }
                    GradientStop { position: 1; color: "transparent" }
                }
                PathAngleArc { centerX: Sky.glowRadius; centerY: Sky.glowRadius; radiusX: Sky.glowRadius; radiusY: Sky.glowRadius; startAngle: 0; sweepAngle: 360 }
            }
        }
        Item {
            rotation: Sky.tilt
            // The accretion disc: a radial glow squashed to the low viewing angle.
            Shape {
                readonly property real r: Sky.discRadius
                x: -r; y: -r; width: 2 * r; height: 2 * r
                opacity: root.lit ? 0.55 + 0.4 * root.high : 0.15
                transform: Scale { origin.x: Sky.discRadius; origin.y: Sky.discRadius; yScale: Sky.discFlat }
                ShapePath {
                    strokeColor: "transparent"
                    fillGradient: RadialGradient {
                        centerX: Sky.discRadius; centerY: Sky.discRadius; focalX: centerX; focalY: centerY; centerRadius: Sky.discRadius; focalRadius: 0
                        GradientStop { position: 0.2; color: "transparent" }
                        GradientStop { position: 0.26; color: Qt.alpha(Design.coldCore, 0.95) }
                        GradientStop { position: 0.45; color: Qt.alpha(Design.coldRim, 0.4) }
                        GradientStop { position: 1; color: "transparent" }
                    }
                    PathAngleArc { centerX: Sky.discRadius; centerY: Sky.discRadius; radiusX: Sky.discRadius; radiusY: Sky.discRadius; startAngle: 0; sweepAngle: 360 }
                }
            }
            // The whole path the time takes, then what is still to go, bright.
            Shape {
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeColor: Design.coldLine
                    strokeWidth: 1
                    fillColor: "transparent"
                    PathPolyline { path: Sky.spiral(0, 1).map(p => Qt.point(p.x, p.y)) }
                }
                ShapePath {
                    strokeColor: Qt.alpha(Design.coldStar, 0.85)
                    strokeWidth: 1.6
                    fillColor: "transparent"
                    PathPolyline { path: Sky.spiral(root.u, 1).map(p => Qt.point(p.x, p.y)) }
                }
            }
            // The matter still to fall: brighter and larger nearer the hole.
            Repeater {
                model: root.lit && root.u < 1 ? Sky.matterCount : 0
                Rectangle {
                    required property int index
                    readonly property real at: root.u + (1 - root.u) * (index + 1) / (Sky.matterCount + 1)
                    readonly property var p: Sky.spiralAt(at)
                    width: 2 * (1.4 + 1.4 * at)
                    height: width
                    radius: width / 2
                    x: p.x - width / 2
                    y: p.y - height / 2
                    color: Design.coldCore
                    opacity: 0.3 + 0.5 * at
                }
            }
            // The hole, its photon ring, and the far side of the disc lensed over the top.
            Rectangle {
                x: -Sky.holeRadius; y: -Sky.holeRadius; width: 2 * Sky.holeRadius; height: width; radius: width / 2
                color: Design.voidFill
                border.width: 1.5
                border.color: Design.coldCore
            }
            Shape {
                preferredRendererType: Shape.CurveRenderer
                opacity: root.lit ? 0.55 + 0.4 * root.high : 0.15
                ShapePath {
                    strokeColor: Design.coldCore
                    strokeWidth: 2
                    fillColor: "transparent"
                    startX: -Sky.holeRadius * 1.85; startY: -8
                    PathQuad { controlX: 0; controlY: -Sky.holeRadius * 2.1; x: Sky.holeRadius * 1.85; y: -8 }
                }
            }
            // Now: the pulsing light, falling in.
            Item {
                objectName: "timers.light"
                readonly property var p: Sky.spiralAt(root.u)
                x: p.x
                y: p.y
                visible: root.lit && root.u < 1
                Rectangle {
                    readonly property real r: Sky.haloRadius * (1 + 1.4 * breath.value)
                    x: -r; y: -r; width: 2 * r; height: 2 * r; radius: r
                    color: "transparent"
                    border.width: 1.5
                    border.color: Design.coldCore
                    opacity: root.running ? 0.7 * (1 - breath.value) : 0.4
                }
                Rectangle {
                    readonly property real r: Sky.beaconRadius * (1 - 0.3 * breath.value)
                    x: -r; y: -r; width: 2 * r; height: 2 * r; radius: r
                    color: Design.coldCore
                    opacity: 1 - 0.6 * breath.value
                }
            }
        }
    }
    // The breath: only while a timer runs, and only in Overdrive (Silent is still, Z146); a cue, so reduced motion
    // and hidden rooms hold it still too.
    Pulse {
        id: breath
        scope: root
        name: "timers.light"
        repeat: root.running && root.lit && Motion.overdrive
        attack: Sky.beaconMs
        release: Sky.beaconMs
    }

    // The planet: its dark face, and the thin air along the horizon, lit by the disc while it stands high.
    Shape {
        id: planet
        objectName: "timers.planet"
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        readonly property real rx: Sky.planetRx * root.width
        readonly property real ry: Sky.planetRy * root.width
        readonly property real cy: Sky.horizonY * root.height + ry
        ShapePath {
            strokeColor: Qt.alpha(Design.atmosphere, root.lit ? 0.25 + 0.55 * root.high : 0.08)
            strokeWidth: Sky.airWidth
            fillColor: Design.voidFill
            PathAngleArc { centerX: root.width / 2; centerY: planet.cy; radiusX: planet.rx; radiusY: planet.ry; startAngle: 180; sweepAngle: 180 }
        }
        ShapePath {
            strokeColor: Qt.alpha(Design.atmosphere, root.lit ? 0.04 + 0.09 * root.high : 0.015)
            strokeWidth: Sky.airGlow
            fillColor: "transparent"
            PathAngleArc { centerX: root.width / 2; centerY: planet.cy; radiusX: planet.rx + Sky.airGlow / 2; radiusY: planet.ry + Sky.airGlow / 2; startAngle: 180; sweepAngle: 180 }
        }
    }
}
