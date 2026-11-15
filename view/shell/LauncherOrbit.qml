import QtQuick
import QtQuick.Shapes
import qs.view.cues
import qs.view.ui
import "LauncherLayout.js" as Layout

// The launcher's star chart (Z196): every result rides one closed orbit, seen tilted. The pick sits at perigee (the
// bottom, nearest you) inside an accretion ring, its name large under it; the others pair up left and right by rank,
// the last at apogee. Symmetric about the island's axis for any count.
//
// `turn` is the selection, unwrapped (it counts every step, so the orbit always swings the short way and keeps
// swinging past the wrap). `spin` follows it: bodies travel along the ring, never across it. A new result set jumps
// (no swing) and its bodies pop in by rank. On open the orbit draws itself in; each new pick flares the ring once
// and its name rises. Nothing moves at rest.
Item {
    id: root
    property var results: []
    property int turn: 0
    readonly property int count: results.length
    readonly property int selected: count ? ((turn % count) + count) % count : 0
    readonly property var pick: results[selected] ?? null
    signal chosen(int index)
    signal step(int by)

    implicitWidth: Layout.contentWidth
    implicitHeight: Layout.chartHeight

    readonly property real cx: Layout.orbitX
    readonly property real cy: Layout.orbitY
    readonly property real perigeeY: cy + Layout.orbitRy

    // What colour a result burns: apps by spectral class (their rank), the other kinds by what they are.
    function tint(row, rank: int): color {
        if (!row) return Design.faint;
        if (row.blocked) return Design.danger;
        if (row.ready === false) return Design.faint;
        switch (row.kind) {
        case "verb": return Design.pulsar;
        case "command": return Design.comet;
        case "search": return Design.nebula;
        case "calc": case "convert": return Design.binary;
        case "file": return Design.asteroid;
        case "setting": return Design.moon;
        case "plugin": return Design.quasar;
        case "clip": return Design.satellite;
        default: return Design.starColor(rank);
        }
    }
    readonly property color pickTint: tint(pick, selected)

    // The swing.
    property real spin: 0
    NumberAnimation {
        id: swing
        target: root
        property: "spin"
        duration: Motion.scaled(Layout.swingMs)
        easing.type: Easing.OutBack
        easing.overshoot: Motion.overshoot
    }
    property var shownResults: null
    onTurnChanged: {
        if (results !== shownResults || !Motion.live(root)) {
            swing.stop();
            spin = turn;
            return;
        }
        swing.stop();
        swing.from = spin;
        swing.to = turn;
        swing.start();
        flare();
    }
    onResultsChanged: {
        swing.stop();
        spin = turn;
        shownResults = results;
        flare();
    }

    // Where body i rides now: an angle on the ellipse, 90° (perigee) for the pick, + to the right.
    function angleOf(i: int): real {
        return Math.PI / 2 - 2 * Math.PI * (i - spin) / Math.max(1, count);
    }
    // How close body i is to perigee, 1 there, 0 one step or more away (the ring stands in for it).
    function nearness(i: int): real {
        let off = (i - spin) % count;
        if (off > count / 2) off -= count;
        if (off < -count / 2) off += count;
        return Math.max(0, 1 - Math.abs(off));
    }

    // One-shot cues: the orbit drawing in, the ring's flare and the headline's rise.
    property real drawn: 0
    NumberAnimation on drawn { id: drawIn; running: false; from: 0; to: 1; duration: Motion.scaled(Layout.drawMs); easing.type: Easing.OutCubic }
    property real flared: 1
    NumberAnimation on flared { id: flaring; running: false; from: 0; to: 1; duration: Motion.scaled(Layout.revealMs); easing.type: Easing.OutCubic }
    function flare(): void {
        if (!Motion.live(root)) { flared = 1; return; }
        flaring.restart();
    }
    Component.onCompleted: {
        shownResults = results;
        if (Motion.live(root)) drawIn.start(); else drawn = 1;
    }

    // The sky behind: a few fixed points in spectral tints (static; drawn once).
    Repeater {
        model: Layout.sky
        delegate: Rectangle {
            required property var modelData
            required property int index
            x: modelData[0] * root.width
            y: modelData[1] * root.height
            width: modelData[2]
            height: width
            radius: width / 2
            color: Design.starColor(index % Design.spectral.length)
            opacity: 0.7
        }
    }

    // The chart: outer and inner orbits, the axes and the orbit the bodies ride (drawn in on open).
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: Qt.alpha(Design.line, 0.45)
            strokeWidth: 1
            fillColor: "transparent"
            PathAngleArc { centerX: root.cx; centerY: root.cy; radiusX: Layout.orbitRx * 1.24; radiusY: Layout.orbitRy * 1.32; startAngle: 90; sweepAngle: 360 * root.drawn }
        }
        ShapePath {
            strokeColor: Qt.alpha(Design.line, 0.6)
            strokeWidth: 1
            strokeStyle: ShapePath.DashLine
            dashPattern: [1, 5]
            fillColor: "transparent"
            PathAngleArc { centerX: root.cx; centerY: root.cy; radiusX: Layout.orbitRx * 0.72; radiusY: Layout.orbitRy * 0.7; startAngle: 90; sweepAngle: -360 * root.drawn }
        }
        ShapePath {
            strokeColor: Qt.alpha(root.pickTint, 0.55)
            strokeWidth: 1.5
            fillColor: "transparent"
            PathAngleArc { centerX: root.cx; centerY: root.cy; radiusX: Layout.orbitRx; radiusY: Layout.orbitRy; startAngle: 90; sweepAngle: 360 * root.drawn }
        }
        ShapePath {
            strokeColor: Qt.alpha(Design.line, 0.5)
            strokeWidth: 1
            strokeStyle: ShapePath.DashLine
            dashPattern: [2, 6]
            fillColor: "transparent"
            startX: root.cx; startY: 0
            PathLine { x: root.cx; y: root.perigeeY - Layout.perigeeRadius }
            PathMove { x: root.cx - Layout.orbitRx * 1.24 * root.drawn; y: root.cy }
            PathLine { x: root.cx + Layout.orbitRx * 1.24 * root.drawn; y: root.cy }
        }
    }
    // The barycentre.
    Rectangle {
        x: root.cx - width / 2
        y: root.cy - height / 2
        width: 2 * Design.baseline
        height: width
        radius: width / 2
        color: Design.line
    }

    LauncherScenery {
        anchors.fill: parent
        kind: root.pick?.kind ?? ""
        tint: root.pickTint
        typed: root.sumParts[0] ?? ""
        answer: root.sumParts[1] ?? ""
        revealed: root.flared
    }

    // Perigee: the pick's halo, its accretion ring (tilted −12°) and the flare.
    Item {
        id: perigee
        x: root.cx
        y: root.perigeeY
        visible: root.count > 0
        Shape {
            readonly property real r: Layout.perigeeRadius * 2.1
            id: halo
            x: -r; y: -r; width: 2 * r; height: 2 * r
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: "transparent"
                fillGradient: RadialGradient {
                    centerX: halo.r; centerY: halo.r; focalX: halo.r; focalY: halo.r; centerRadius: halo.r; focalRadius: 0
                    GradientStop { position: 0; color: Qt.alpha(root.pickTint, 0.42) }
                    GradientStop { position: 0.45; color: Qt.alpha(root.pickTint, 0.14) }
                    GradientStop { position: 1; color: Qt.alpha(root.pickTint, 0) }
                }
                PathAngleArc { centerX: halo.r; centerY: halo.r; radiusX: halo.r; radiusY: halo.r; startAngle: 0; sweepAngle: 360 }
            }
        }
        // The accretion disc, leaning −12° with the rest of the language, behind the ring.
        Shape {
            x: -Layout.perigeeRadius * 1.6; y: x; width: -2 * x; height: width
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: Qt.alpha(root.pickTint, 0.8)
                strokeWidth: 1
                strokeStyle: ShapePath.DashLine
                dashPattern: [3, 3]
                fillColor: "transparent"
                PathAngleArc { centerX: Layout.perigeeRadius * 1.6; centerY: centerX; radiusX: Layout.perigeeRadius * 1.5; radiusY: Layout.perigeeRadius * 0.36; startAngle: 0; sweepAngle: 360 }
            }
            transform: Matrix4x4 {
                matrix: Qt.matrix4x4(1, Design.shear, 0, -Design.shear * Layout.perigeeRadius * 1.6, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
            }
        }
        Shape {
            x: -Layout.perigeeRadius - 1; y: x; width: -2 * x; height: width
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: root.pickTint
                strokeWidth: 2
                fillColor: Qt.alpha(Design.islandFill, 0.85)
                PathAngleArc { centerX: Layout.perigeeRadius + 1; centerY: centerX; radiusX: Layout.perigeeRadius; radiusY: Layout.perigeeRadius; startAngle: 0; sweepAngle: 360 }
            }
        }
        Rectangle {
            readonly property real r: Layout.perigeeRadius * (1 + root.flared)
            x: -r; y: -r; width: 2 * r; height: 2 * r
            radius: r
            color: "transparent"
            border.width: 2
            border.color: root.pickTint
            opacity: 1 - root.flared
            visible: opacity > 0.01
        }
        // What the pick is: its own icon, else its kind's glyph.
        Image {
            id: icon
            anchors.centerIn: parent
            width: Layout.perigeeRadius
            height: width
            sourceSize: Qt.size(2 * width, 2 * width)
            source: root.pick?.icon ?? ""
            visible: status === Image.Ready
            asynchronous: true
            smooth: true
        }
        MaterialSymbol {
            anchors.centerIn: parent
            visible: !icon.visible
            text: root.pick?.glyph || (({ calc: "calculate", convert: "straighten", command: "terminal", search: "travel_explore", verb: "bolt",
                     file: "description", setting: "settings", plugin: "extension", clip: "content_paste" })[root.pick?.kind] ?? "apps")
            iconSize: Layout.perigeeRadius * 0.8 // scale: the glyph fills the ring
            color: root.pickTint
        }
        MouseArea {
            x: -Layout.perigeeRadius; y: x; width: -2 * x; height: width
            cursorShape: Qt.PointingHandCursor
            onClicked: root.chosen(root.selected)
        }
    }

    // The bodies.
    Repeater {
        model: root.results
        delegate: LauncherBody {
            objectName: "launcherBody"
            required property var modelData
            required property int index
            readonly property real angle: root.angleOf(index)
            row: modelData
            rank: index
            tint: root.tint(modelData, index)
            x: root.cx + Layout.orbitRx * Math.cos(angle)
            y: root.cy + Layout.orbitRy * Math.sin(angle)
            depth: (Math.sin(angle) + 1) / 2
            eclipse: root.nearness(index)
            outward: Math.cos(angle) >= 0
            onChosen: root.chosen(index)
        }
    }

    // The pick's name, rising under perigee, and what Enter does.
    readonly property bool sum: pick?.kind === "calc" || pick?.kind === "convert"
    readonly property var sumParts: sum ? String(pick.name).split(" = ") : []
    FText {
        id: headline
        objectName: "launcherHeadline"
        anchors.horizontalCenter: parent.horizontalCenter
        y: Layout.headlineY + (1 - root.flared) * 2 * Design.baseline
        opacity: Math.min(1, 0.3 + root.flared)
        width: parent.width - 4 * Design.baseline
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        headline: true
        text: root.sum ? "= " + (root.sumParts[1] ?? "") : root.pick?.name ?? ""
        font.capitalization: root.sum ? Font.MixedCase : Font.AllUppercase
        font.pixelSize: Design.headline
        font.weight: Font.Black
        color: root.pickTint
        transform: Matrix4x4 {
            matrix: Qt.matrix4x4(1, Design.shear, 0, -Design.shear * headline.height / 2, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
        }
    }
    FText {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: headline.bottom
        width: parent.width - 4 * Design.baseline
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        technical: true
        font.pixelSize: Design.caption
        color: Design.muted
        text: {
            const row = root.pick;
            if (!row) return "";
            if (row.blocked) return "> BLOCKED · SESSION";
            const enter = { app: "LAUNCH", verb: "RUN", command: "RUN", search: "OPEN", calc: "COPY", convert: "COPY",
                            file: "OPEN", setting: "OPEN", plugin: "RUN", clip: "PASTE" }[row.kind ?? "app"] ?? "GO";
            const what = root.sum ? root.sumParts[0] : row.kind === "app" ? "CLASS " + "OBAFGKM"[Math.min(root.selected, 6)] + (row.description ? " · " + row.description : "") : row.description;
            return what + (row.ready === false ? "" : " · ↵ " + enter);
        }
    }

    // The wheel swings the orbit, a step per notch.
    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => root.step(event.angleDelta.y > 0 ? -1 : 1)
    }
}
