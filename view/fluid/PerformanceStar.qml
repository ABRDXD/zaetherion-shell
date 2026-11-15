import QtQuick
import QtQuick.Shapes
import qs.view.cues
import qs.view.ui
import "PerformanceStarLayout.js" as Star

// The machine as a star (Fluid Performance, owner's pick "A"), in depth. A gravity well reaches back under it, pulled
// down by its mass (memory in use). Its colour is the CPU's temperature along the spectral classes; its surface darkens
// toward the limb as a real star's does; a faint corona surrounds it. The last minutes of CPU load wrap around it as a
// light-curve ring, swelling where the load was high (now at the top). The GPU is a companion and, in Overdrive, one
// shell per core brightens with that core's load and the heaviest processes orbit as cold planets. Orbits are seen in
// depth: their far halves pass behind the star, faint; their near halves cross in front; planets shrink at the back.
Item {
    id: root
    property real load: 0            // CPU, 0–1
    property var temperature: null   // °C, or null
    property real memory: 0          // in use, 0–1
    property var history: []         // CPU load samples, oldest first
    property bool gpuAvailable: false
    property real gpuLoad: 0
    property var gpuTemperature: null
    property var cores: []           // Overdrive: each core's load, 0–1
    property var planets: []         // Overdrive: [{name, rss (MiB)}], heaviest first
    readonly property real cx: width / 2
    readonly property real cy: height * 0.46

    // Temperature → colour: heat 1 is the hottest class (first in Design.spectral), 0 the coolest (last).
    function tint(heat): color {
        if (heat === null) return Qt.color(Design.spectral[3]);
        const at = (1 - heat) * (Design.spectral.length - 1), i = Math.floor(at), f = at - i;
        // The classes are stored as text: make them colours before mixing their channels.
        const a = Qt.color(Design.spectral[i]), b = Qt.color(Design.spectral[Math.min(i + 1, Design.spectral.length - 1)]);
        return Qt.rgba(a.r + (b.r - a.r) * f, a.g + (b.g - a.g) * f, a.b + (b.b - a.b) * f, 1);
    }
    readonly property var heat: Star.heat(temperature ?? null)
    readonly property color starColour: tint(heat !== null ? heat : load)
    readonly property color gpuColour: tint(Star.heat(gpuTemperature ?? null) ?? gpuLoad)

    // Eased so a sample moves the star rather than snapping it.
    property real shownLoad: load
    property real shownMemory: memory
    Tween on shownLoad { scope: root; NumberAnimation { duration: Motion.scaled(900); easing.type: Easing.OutCubic } }
    Tween on shownMemory { scope: root; NumberAnimation { duration: Motion.scaled(900); easing.type: Easing.OutCubic } }

    readonly property real coreR: height * (Star.coreMin + (Star.coreMax - Star.coreMin) * shownMemory)
    readonly property real glowR: height * (Star.glowBase + Star.glowLoad * shownLoad)
    readonly property real ringR: coreR + height * Star.shellGap * (Math.max(8, cores.length) + 3)

    // A point on orbit k at angle a, and how near it is (0 back … 1 front).
    function orbitPoint(k: int, a: real): point {
        const p = Star.onOrbit(Star.orbits[k][0] * width, Star.orbits[k][1] * height, a);
        return Qt.point(cx + p.x, cy + p.y);
    }
    function depthOf(a: real): real { return (Math.sin(a) + 1) / 2; }
    function arc(k: int, from: real, to: real): var {
        const pts = [];
        for (let i = 0; i <= 64; i++) pts.push(orbitPoint(k, from + (to - from) * i / 64));
        return pts;
    }

    GravityWell {
        objectName: "performanceWell"
        anchors.fill: parent
        mass: root.shownMemory
        wellX: root.cx
    }

    // The far halves of the orbits, behind the star.
    Repeater {
        model: Star.orbits.length
        Shape {
            required property int index
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: Qt.alpha(Design.coldLine, 0.55)
                strokeWidth: 1
                fillColor: "transparent"
                PathPolyline { path: root.arc(index, Math.PI, 2 * Math.PI) }
            }
        }
    }

    // The glow and the corona.
    Shape {
        id: glow
        readonly property real r: root.glowR
        x: root.cx - r; y: root.cy - r; width: 2 * r; height: 2 * r
        ShapePath {
            strokeColor: "transparent"
            fillGradient: RadialGradient {
                centerX: glow.r; centerY: glow.r; focalX: glow.r; focalY: glow.r; centerRadius: glow.r; focalRadius: 0
                GradientStop { position: 0; color: Qt.alpha(root.starColour, 0.9) }
                GradientStop { position: 0.3; color: Qt.alpha(root.starColour, 0.45) }
                GradientStop { position: 0.62; color: Qt.alpha(root.starColour, 0.1) }
                GradientStop { position: 1; color: "transparent" }
            }
            PathAngleArc { centerX: glow.r; centerY: glow.r; radiusX: glow.r; radiusY: glow.r; startAngle: 0; sweepAngle: 360 }
        }
    }
    Repeater {
        model: 3
        Rectangle {
            required property int index
            readonly property real r: root.coreR * (1.5 + 0.55 * index)
            x: root.cx - r; y: root.cy - r; width: 2 * r; height: 2 * r; radius: r
            color: "transparent"
            border.width: 1
            border.color: Qt.alpha(root.starColour, 0.16 - 0.04 * index)
        }
    }

    // One shell per core (Overdrive), brighter the busier.
    Repeater {
        objectName: "performanceShells"
        model: root.cores
        Rectangle {
            required property real modelData
            required property int index
            readonly property real r: root.coreR + root.height * Star.shellGap * (index + 1)
            x: root.cx - r; y: root.cy - r; width: 2 * r; height: 2 * r; radius: r
            color: "transparent"
            border.width: 1.4
            border.color: Qt.alpha(root.starColour, 0.08 + 0.6 * Math.max(0, Math.min(1, modelData)))
        }
    }

    // The light curve: the last minutes of load around the star, now at the top, older clockwise.
    Shape {
        objectName: "performanceLightCurve"
        anchors.fill: parent
        visible: root.history.length > 1
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: Qt.alpha(root.starColour, 0.7)
            strokeWidth: 1.4
            fillColor: "transparent"
            PathPolyline {
                path: {
                    const h = root.history, n = h.length, pts = [];
                    for (let i = 0; i < n; i++) {
                        const a = -Math.PI / 2 + 2 * Math.PI * (n - 1 - i) / Math.max(1, n);
                        const r = root.ringR + root.height * 0.05 * Math.max(0, Math.min(1, h[i]));
                        pts.push(Qt.point(root.cx + r * Math.cos(a), root.cy + r * Math.sin(a)));
                    }
                    return pts;
                }
            }
        }
        ShapePath {
            strokeColor: Qt.alpha(Design.coldLine, 0.8)
            strokeWidth: 1
            strokeStyle: ShapePath.DashLine
            dashPattern: [1, 4]
            fillColor: "transparent"
            PathAngleArc { centerX: root.cx; centerY: root.cy; radiusX: root.ringR; radiusY: root.ringR; startAngle: 0; sweepAngle: 360 }
        }
    }

    // Now, where the light curve begins (the top): a small bright mark, so the gap reads as the present.
    Item {
        objectName: "performanceNow"
        visible: root.history.length > 1
        readonly property real r: root.ringR + root.height * 0.05 * Math.max(0, Math.min(1, root.history[root.history.length - 1] ?? 0))
        x: root.cx
        y: root.cy - r
        Rectangle { x: -3; y: -3; width: 6; height: 6; radius: 3; color: Design.coldCore }
        FText {
            anchors.horizontalCenter: parent.horizontalCenter
            y: -height - Design.baseline * 1.5
            technical: true
            font.pixelSize: Design.caption
            color: Design.coldInk
            text: "NOW"
        }
    }

    // The star: limb-darkened, its centre near white.
    Shape {
        id: disc
        objectName: "performanceCore"
        readonly property real r: root.coreR
        x: root.cx - r; y: root.cy - r; width: 2 * r; height: 2 * r
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: "transparent"
            fillGradient: RadialGradient {
                centerX: disc.r; centerY: disc.r; focalX: disc.r * 0.85; focalY: disc.r * 0.85; centerRadius: disc.r; focalRadius: 0
                GradientStop { position: 0; color: Qt.lighter(root.starColour, 1.25) }
                GradientStop { position: 0.6; color: root.starColour }
                GradientStop { position: 0.92; color: Qt.darker(root.starColour, 1.35) }
                GradientStop { position: 1; color: Qt.darker(root.starColour, 1.8) }
            }
            PathAngleArc { centerX: disc.r; centerY: disc.r; radiusX: disc.r; radiusY: disc.r; startAngle: 0; sweepAngle: 360 }
        }
    }

    // The near halves of the orbits, in front of the star.
    Repeater {
        model: Star.orbits.length
        Shape {
            required property int index
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: Qt.alpha(Design.coldRim, 0.28)
                strokeWidth: 1
                fillColor: "transparent"
                PathPolyline { path: root.arc(index, 0, Math.PI) }
            }
        }
    }

    // The GPU: a companion star on its orbit.
    Item {
        objectName: "performanceCompanion"
        visible: root.gpuAvailable
        readonly property point p: root.orbitPoint(Star.gpuOrbit, Star.gpuAngle)
        x: p.x
        y: p.y
        z: root.depthOf(Star.gpuAngle) > 0.5 ? 2 : -1
        ColdStar { radius: Design.baseline * (6 + 6 * root.gpuLoad) }
        Rectangle {
            readonly property real d: Design.baseline * (2 + 1.5 * root.gpuLoad)
            x: -d / 2; y: -d / 2; width: d; height: d; radius: d / 2
            color: root.gpuColour
        }
    }

    // The heaviest processes as planets, lit from the star, smaller and dimmer at the back (Overdrive).
    Repeater {
        model: root.planets.slice(0, Star.planetCount)
        Item {
            required property var modelData
            required property int index
            readonly property int orbit: index % Star.orbits.length
            readonly property real angle: Star.planetAngles[index]
            readonly property point p: root.orbitPoint(orbit, angle)
            readonly property real depth: root.depthOf(angle)
            readonly property real size: (0.6 + 0.4 * depth) * Math.max(Design.baseline * 2, Math.min(Design.baseline * 7, Design.baseline * (1.5 + Math.sqrt(modelData.rss ?? 0) / 8)))
            x: p.x
            y: p.y
            z: depth > 0.5 ? 2 : -1
            opacity: 0.55 + 0.45 * depth
            ColdPlanet { size: parent.size; litRight: parent.p.x < root.cx; lit: Math.min(1, Math.abs(parent.p.x - root.cx) / (root.width * 0.2)); depth: parent.depth }
            FText {
                anchors.horizontalCenter: parent.horizontalCenter
                y: parent.size / 2 + Design.baseline
                technical: true
                font.pixelSize: Design.caption
                color: Design.coldInk
                text: String(modelData.name ?? "")
            }
        }
    }
}
