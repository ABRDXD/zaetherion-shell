import QtQuick
import QtQuick.Shapes
import qs.view.cues
import qs.view.ui
import "WorkspaceLayout.js" as Layout

// The workspace switch on the island (Z199, owner's pick C2): an edge-on system seen from its own plane, a slot onto
// something far larger. A small cold star sits on the island's axis; the workspaces are planets on one orbit, sized by
// their windows; the current one transits the star, a dark disc on its face. The others are silhouettes with a thin
// crescent on the side facing the star, smaller and dimmer behind it. A switch turns the whole system the short way
// round, slowly and without bounce, and one cold glint runs along the plane. Nothing moves once it has turned.
//
// ids: the workspaces shown, in order; active: the current id; windows: id → window count.
Item {
    id: root
    property var ids: []
    property string active: ""
    property var windows: ({})
    readonly property int count: ids.length
    readonly property int current: Math.max(0, ids.indexOf(active))

    clip: true

    // The turn, unwrapped so the system always turns the short way round, and `spin` following it. Plain values,
    // set once at start: a binding would move `spin` to the new turn before the animation could start from the old.
    property int turn: 0
    property real spin: 0
    property bool ready: false
    Component.onCompleted: { turn = current; spin = current; ready = true; }  // it opens already in place
    NumberAnimation {
        id: turning
        target: root
        property: "spin"
        duration: Motion.scaled(Layout.turnMs)
        easing.type: Easing.OutCubic
    }
    onCurrentChanged: {
        if (!ready || count < 2) return;
        let step = (current - ((turn % count) + count) % count) % count;
        if (step > count / 2) step -= count;
        if (step < -count / 2) step += count;
        turn += step;
        if (!Motion.live(root)) {
            spin = turn;
            return;
        }
        turning.stop();
        turning.from = spin;
        turning.to = turn;
        turning.start();
        glinting.restart();
    }

    readonly property real cx: width / 2
    // Body i's place on the orbit: its angle from the front (0 = in transit), + to the right.
    function phase(i: int): real {
        return 2 * Math.PI * (i - spin) / Math.max(1, count);
    }

    // Dust: a few faint cold points, fixed.
    Repeater {
        model: Layout.dust
        delegate: Rectangle {
            required property var modelData
            x: modelData[0] * root.width
            y: modelData[1] * root.height
            width: modelData[2]
            height: width
            radius: width / 2
            color: Design.coldInk
            opacity: modelData[3]
        }
    }
    // The plane: a faint haze along it and the orbit itself, a hairline seen edge-on.
    Rectangle {
        y: Layout.planeY - Design.baseline
        width: parent.width
        height: 2 * Design.baseline
        gradient: Gradient {
            GradientStop { position: 0; color: "transparent" }
            GradientStop { position: 0.5; color: Qt.alpha(Design.coldLine, 0.55) }
            GradientStop { position: 1; color: "transparent" }
        }
    }
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: Design.coldLine
            strokeWidth: 0.8
            fillColor: "transparent"
            PathAngleArc { centerX: root.cx; centerY: Layout.planeY; radiusX: Layout.orbitRx - 10; radiusY: Layout.orbitRy - 2; startAngle: 0; sweepAngle: 360 }
        }
    }

    // The star, small and cold.
    ColdStar {
        radius: Layout.starRadius
        x: root.cx - radius
        y: Layout.planeY - radius
        z: 2
    }

    // The planets. Behind the star (the back of the orbit) they pass under it; in front, over it.
    Repeater {
        model: root.ids
        delegate: Item {
            id: planet
            objectName: "workspacePlanet"
            required property string modelData
            required property int index
            readonly property real angle: root.phase(index)
            readonly property real front: Math.cos(angle)          // 1 in transit, −1 behind the star
            readonly property real depth: (front + 1) / 2
            // 1 crossing the star's face, 0 one step or more away (the angle wrapped to −π…π).
            readonly property real crossing: front <= 0 ? 0
                : Math.max(0, 1 - Math.abs(Math.atan2(Math.sin(angle), front)) * root.count / (2 * Math.PI))
            readonly property int windows: Number(root.windows[modelData] ?? 0)
            readonly property real free: Layout.planetSize(windows) * (Layout.farScale + (1 - Layout.farScale) * depth)
                                        * (1 + Layout.transitGrowth * crossing)
            // Crossing the star, a world never covers it: the star's light rings it (a transit, not an eclipse).
            readonly property real size: crossing > 0 ? Math.min(free, free + (2 * Layout.starRadius * Layout.transitMax - free) * crossing) : free
            // The lit crescent faces the star: on the left of the star the right edge is lit, and the reverse.
            readonly property bool litRight: Math.sin(angle) < 0
            readonly property real lit: Math.abs(Math.sin(angle))   // full beside the star, none in transit
            x: root.cx + Layout.orbitRx * Math.sin(angle)
            y: Layout.planeY + Layout.orbitRy * front
            z: front > 0 ? 3 : 1
            opacity: front > 0 ? 1 : Layout.farOpacity
            ColdPlanet {
                size: planet.size
                lit: planet.lit
                litRight: planet.litRight
                depth: planet.depth
            }
        }
    }

    // The glint: once per switch, a cold line along the plane, brightest at the star.
    // One plain animation (the project's motion rule): the line rises over the first 35 % and fades over the rest.
    property real glintT: 1
    readonly property real glint: glintT < 0.35 ? glintT / 0.35 : (1 - glintT) / 0.65
    NumberAnimation {
        id: glinting
        target: root
        property: "glintT"
        from: 0
        to: 1
        duration: Motion.scaled(Layout.glintMs)
        easing.type: Easing.InOutSine
    }
    Rectangle {
        x: root.cx - 2 * Layout.starRadius
        y: Layout.planeY
        z: 4
        width: 4 * Layout.starRadius
        height: 1
        opacity: root.glint * 0.9
        visible: opacity > 0.01
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: "transparent" }
            GradientStop { position: 0.5; color: Design.coldStar }
            GradientStop { position: 1; color: "transparent" }
        }
    }

    // The scale: one hairline tick per workspace, the current one raised, inhabited ones a little taller.
    Rectangle {
        x: Layout.scaleInset
        y: Layout.scaleY
        width: root.width - 2 * Layout.scaleInset
        height: 1
        color: Qt.alpha(Design.coldLine, 0.6)
    }
    Repeater {
        model: root.ids
        delegate: Rectangle {
            required property string modelData
            required property int index
            readonly property bool here: index === root.current
            readonly property real h: here ? Layout.tickCurrent : Number(root.windows[modelData] ?? 0) > 0 ? Layout.tickInhabited : Layout.tickEmpty
            x: Layout.scaleInset + index * (root.width - 2 * Layout.scaleInset) / Math.max(1, root.count - 1)
            y: Layout.scaleY - h + 1
            width: 1
            height: h
            color: here ? Design.coldStar : Design.coldLine
        }
    }
    FText {
        objectName: "workspaceReadout"
        anchors.horizontalCenter: parent.horizontalCenter
        y: Layout.readoutY
        technical: true
        font.pixelSize: Design.caption
        font.weight: Font.Light
        font.letterSpacing: 2
        color: Design.coldInk
        readonly property int windowsHere: Number(root.windows[root.active] ?? 0)
        text: String(root.active).padStart(2, "0") + " / " + String(root.count).padStart(2, "0") + "   ·   "
              + windowsHere + (windowsHere === 1 ? " WINDOW" : " WINDOWS")
    }
}
