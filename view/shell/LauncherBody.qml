import QtQuick
import QtQuick.Shapes
import qs.view.cues
import qs.view.ui
import "LauncherLayout.js" as Layout

// One result riding the launcher's orbit (Z196), drawn as what it is: an app is a star tinted by its spectral class,
// a FART verb a pulsar with its beam, `>cmd` a comet with a tail pointing away from the centre, `?term` a nebula,
// a sum a binary pair. The orbit places it (x, y at its centre) and gives its depth: 0 at apogee (back, small, dim)
// to 1 at perigee (front). At perigee the ring stands for it, so `eclipse` (0–1) fades the body out there.
// It pops in once when created (a new result set), staggered by rank; nothing moves at rest.
Item {
    id: root
    property var row: ({})
    property int rank: 0
    property color tint: Design.ink
    property real depth: 0
    property real eclipse: 0
    property bool outward: true   // on the right half: a comet's tail and a pulsar's beam lean away from the centre
    property real lit: 1          // a planet's crescent: full beside the star, none straight behind or in front
    signal chosen()

    readonly property string kind: row?.kind ?? "app"
    readonly property bool pair: kind === "calc" || kind === "convert"
    readonly property bool planet: kind === "app"  // apps are planets (Z199): no glow, a crescent toward the star
    readonly property real core: Math.round(7 + 13 * depth)
    readonly property real shown: (1 - eclipse) * born
    readonly property bool front: depth > 0.5  // the front half of the orbit reads larger and brighter
    width: 0
    height: 0
    z: depth
    opacity: (0.4 + 0.6 * depth) * Math.min(1, born * 1.5)

    property real born: 0
    NumberAnimation on born {
        id: birth
        running: false
        from: 0
        to: 1
        duration: Motion.scaled(Layout.revealMs / 2)
        easing.type: Easing.OutBack
        easing.overshoot: Motion.overshoot
    }
    Timer {
        id: stagger
        interval: root.rank * Layout.birthStagger
        onTriggered: birth.start()
    }
    Component.onCompleted: {
        if (Motion.live(root.parent)) stagger.start();
        else born = 1;
    }

    Item {
        id: body
        scale: root.shown
        visible: root.shown > 0.01

        // The glow: a soft disc of the body's colour, larger for a nebula.
        Shape {
            id: glow
            visible: !root.planet
            readonly property real r: root.core * (root.kind === "search" ? 3.2 : 1.9)
            x: -r
            y: -r
            width: 2 * r
            height: 2 * r
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: "transparent"
                fillGradient: RadialGradient {
                    centerX: glow.r; centerY: glow.r; focalX: glow.r; focalY: glow.r
                    centerRadius: glow.r; focalRadius: 0
                    GradientStop { position: 0; color: Qt.alpha(root.tint, root.kind === "search" ? 0.55 : 0.7) }
                    GradientStop { position: 0.35; color: Qt.alpha(root.tint, 0.22) }
                    GradientStop { position: 1; color: Qt.alpha(root.tint, 0) }
                }
                PathAngleArc { centerX: glow.r; centerY: glow.r; radiusX: glow.r; radiusY: glow.r; startAngle: 0; sweepAngle: 360 }
            }
        }
        // The beam (pulsar) or tail (comet), behind the core.
        Rectangle {
            visible: root.kind === "verb"
            width: 2
            height: root.core * 3.4
            x: -1
            y: -height / 2
            color: root.tint
            opacity: 0.85
            rotation: root.outward ? 30 : -30
        }
        Rectangle {
            visible: root.kind === "command"
            width: root.core * 5
            height: 2
            x: root.outward ? 0 : -width
            y: -1
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: root.outward ? root.tint : "transparent" }
                GradientStop { position: 1; color: root.outward ? "transparent" : root.tint }
            }
        }
        // A quasar's twin jets, straight up and down through the core.
        Rectangle {
            visible: root.kind === "plugin"
            width: 2
            height: root.core * 4
            x: -1
            y: -height / 2
            gradient: Gradient {
                GradientStop { position: 0; color: "transparent" }
                GradientStop { position: 0.5; color: root.tint }
                GradientStop { position: 1; color: "transparent" }
            }
        }
        // The core: a disc (a pair for a sum), a tumbling rock for a file, a crescent for a setting, a satellite's
        // body and panels for a clipboard entry.
        Repeater {
            model: root.pair ? 2 : root.planet || root.kind === "file" || root.kind === "clip" ? 0 : 1
            delegate: Rectangle {
                required property int index
                readonly property real d: root.pair ? root.core * 0.7 : root.core
                width: d
                height: d
                radius: d / 2
                x: -d / 2 + (root.pair ? (index ? 0.7 : -0.7) * root.core : 0)
                y: -d / 2
                color: index ? Design.spectral[0] : root.tint
                border.width: root.kind === "search" ? 0 : 1
                border.color: Qt.lighter(root.tint, 1.25)
            }
        }
        ColdPlanet {
            visible: root.planet
            size: root.core
            lit: root.lit
            litRight: !root.outward  // on the left half the star is to the right
            depth: root.depth
        }
        Rectangle {  // the crescent's shadow: the island's dark across most of the disc
            visible: root.kind === "setting" || root.kind === "moon"
            width: root.core
            height: width
            radius: width / 2
            x: -width / 2 + root.core * 0.32
            y: -height / 2 - root.core * 0.12
            color: Design.islandFill
        }
        Rectangle {  // an asteroid: a rough rock, leaning on the −12° line
            visible: root.kind === "file"
            width: root.core * 0.9
            height: root.core * 0.7
            x: -width / 2
            y: -height / 2
            radius: Design.radiusCard
            rotation: -12
            color: root.tint
        }
        Row {        // a satellite: panels either side of a small body
            visible: root.kind === "clip"
            x: -width / 2
            y: -height / 2
            spacing: 1
            Repeater {
                model: 3
                delegate: Rectangle {
                    required property int index
                    width: index === 1 ? root.core * 0.45 : root.core * 0.6
                    height: index === 1 ? root.core * 0.45 : root.core * 0.28
                    anchors.verticalCenter: parent.verticalCenter
                    color: index === 1 ? Qt.lighter(root.tint, 1.2) : root.tint
                }
            }
        }
    }

    // Its name and tag, centred under it; the back of the orbit reads smaller.
    Column {
        x: -Layout.labelWidth / 2
        y: root.core / 2 + Design.baseline
        width: Layout.labelWidth
        opacity: root.shown
        visible: opacity > 0.01
        FText {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            headline: true
            text: root.row?.name ?? ""
            font.pixelSize: root.front ? Design.readout : Design.control
            font.weight: Font.Black
            color: hover.hovered ? root.tint : root.front ? Design.ink : Design.muted
        }
        FText {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            technical: true
            text: root.tag
            font.pixelSize: Design.caption
            color: root.tint
        }
    }
    // The tag: what kind of body, then what the core says about it.
    readonly property string tag: {
        const words = { verb: "PULSAR", command: "COMET", search: "NEBULA", calc: "BINARY", convert: "BINARY",
                        file: "ASTEROID", setting: "MOON", plugin: "QUASAR", clip: "SATELLITE", moon: "MOON" };
        const what = row?.blocked ? "BLOCKED" : words[kind] ?? "";
        const description = row?.description ?? "";
        return what && description ? what + " · " + description : what || description;
    }

    MouseArea {
        x: -Math.max(Design.minHit, root.core) / 2
        y: x
        width: -2 * x
        height: width
        cursorShape: Qt.PointingHandCursor
        onClicked: root.chosen()
        HoverHandler { id: hover }
    }
}
