import qs.view.cues
import QtQuick
import QtQuick.Shapes
import Quickshell

// A round cover inside a ring (MONTAGE.md §5). With `bars` 0 the ring is a thin arc
// carrying the track position; with bars it is an audio ring: radial ticks whose length follows the
// spectrum while `reactive`, coloured in the accent up to the position, so the ring is also the clock of
// the track. The cover is cut round by a ShapePath fill (no offscreen mask; the software renderer ignores
// fillItem and shows the plain disc). Behind it, optionally, the offset accent outline of FART's frames.
Item {
    id: root
    property url source: ""
    property real progress: 0
    property int bars: 0
    property var spectrum: []
    property bool reactive: false
    property bool offsetFrame: false
    property color accent: Design.accent
    // Idle: the cover turns while playing; paused, a comet circles the ring.
    property bool spinning: false
    property bool orbiting: true
    // The ring's depth outside the disc; the ticks grow out to it.
    property real ring: bars > 0 ? Math.round(width * 0.09) : 8
    readonly property real side: Math.min(width, height)
    readonly property real disc: side - 2 * ring
    readonly property real centre: side / 2
    readonly property bool ready: art.status === Image.Ready
    readonly property var levels: reactive && visible ? spectrum : []
    implicitWidth: 120
    implicitHeight: 120

    // The offset frame: the same circle, down and to the left, in the accent outline.
    Rectangle {
        visible: root.offsetFrame
        x: root.ring - root.ring * 0.9
        y: root.ring + root.ring * 0.9
        width: root.disc
        height: root.disc
        radius: width / 2
        color: "transparent"
        border.color: Design.accent
        border.width: 1.5
    }
    Shape {
        width: root.side
        height: root.side
        antialiasing: true
        preferredRendererType: Shape.CurveRenderer
        // The thin ring (no bars): the track, then the played part from the top, clockwise.
        ShapePath {
            strokeColor: root.bars > 0 ? "transparent" : Qt.alpha(Design.line, 0.6)
            strokeWidth: 3
            fillColor: "transparent"
            PathAngleArc { centerX: root.centre; centerY: root.centre; radiusX: root.centre - 2; radiusY: root.centre - 2; startAngle: 0; sweepAngle: 360 }
        }
        ShapePath {
            strokeColor: root.bars > 0 ? "transparent" : root.accent
            strokeWidth: 3
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc { centerX: root.centre; centerY: root.centre; radiusX: root.centre - 2; radiusY: root.centre - 2; startAngle: -90; sweepAngle: 360 * Math.max(0, Math.min(1, root.progress)) }
        }
    }
    // The cover on its own layer, so it can turn like a record while playing (idle, MONTAGE.md §4.5).
    Shape {
        id: platter
        width: root.side
        height: root.side
        antialiasing: true
        preferredRendererType: Shape.CurveRenderer
        transformOrigin: Item.Center
        rotation: 360 * spin.phase
        ShapePath {
            strokeColor: "transparent"
            fillColor: Design.hover
            fillItem: root.ready ? art : null
            fillTransform: PlanarTransform.fromTranslate(root.ring, root.ring)
            PathAngleArc { centerX: root.centre; centerY: root.centre; radiusX: root.disc / 2; radiusY: root.disc / 2; startAngle: -90; sweepAngle: 360 }
        }
    }
    IdleLoop { id: spin; scope: root; name: "cover.spin"; enabled: root.spinning && root.ready; period: 14000 }
    // Paused: a small comet circles the ring, slowly.
    IdleLoop { id: orbit; scope: root; name: "cover.orbit"; enabled: !root.spinning && root.orbiting; period: 7000 }
    Item {
        id: comet
        visible: orbit.running
        width: root.side
        height: root.side
        Rectangle {
            x: root.centre - width / 2
            y: root.bars > 0 ? root.ring * 0.35 : 0
            width: 5
            height: 5
            radius: 2.5
            color: root.accent
        }
        rotation: 360 * orbit.phase
    }
    // The audio ring: one tick per bin, from the disc's edge outwards.
    Repeater {
        model: root.bars
        Rectangle {
            id: tick
            required property int index
            readonly property real angle: index * 360 / root.bars
            readonly property real amplitude: root.levels.length
                ? Math.min(1, Math.max(0, root.levels[Math.floor(index * root.levels.length / root.bars)])) : 0
            readonly property real reach: root.ring - 6
            x: root.centre - width / 2
            y: root.centre - root.disc / 2 - 4 - height
            width: Math.max(2, Math.PI * root.disc / root.bars * 0.42)
            height: Math.max(3, reach * (0.18 + 0.82 * amplitude))
            color: (index + 0.5) / root.bars <= root.progress ? root.accent : Qt.alpha(Design.line, 0.8)
            transform: Rotation {
                origin.x: tick.width / 2
                origin.y: tick.height + 4 + root.disc / 2
                angle: tick.angle
            }
        }
    }
    Image {
        id: art
        x: root.ring
        y: root.ring
        width: root.disc
        height: root.disc
        visible: false
        source: root.source
        sourceSize: Qt.size(Math.ceil(width * (root.QsWindow.window?.screen?.devicePixelRatio ?? 1)), Math.ceil(height * (root.QsWindow.window?.screen?.devicePixelRatio ?? 1)))
        cache: false
        asynchronous: true
        fillMode: Image.PreserveAspectCrop
    }
    MaterialSymbol {
        x: root.centre - width / 2
        y: root.centre - height / 2
        visible: !root.ready
        text: "music_note"
        iconSize: root.disc * 0.4
        color: Design.faint
    }
}
