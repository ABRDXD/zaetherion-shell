import qs.view.cues
import qs.view.strata
import qs.view.ui
import QtQuick

// The elements. The table is one Canvas, painted only when the sheet or the choice changes. The chosen element stands in the gap at the top
// of the table: its symbol cropped huge, its facts, and its atom, shells and electrons drawn to the real counts. In Overdrive, the table
// sweeps in once by atomic number and the electrons circle.
Item {
    id: root
    activeFocusOnTab: true
    Accessible.name: "Periodic table, " + chosen.name
    readonly property var elements: Periodic.elements
    property int chosenZ: Periodic.ofDay(new Date()).z
    property int hoveredZ: 0
    readonly property var chosen: elements[chosenZ - 1]
    readonly property var showing: hoveredZ > 0 ? elements[hoveredZ - 1] : chosen
    readonly property real gap: 2
    readonly property real cellW: Math.floor((width - 17 * gap) / 18)
    readonly property real cellH: Math.floor((height - 8 * gap - 12) / 9)
    function xOf(col) { return (col - 1) * (cellW + gap); }
    function yOf(row) { return (row - 1) * (cellH + gap) + (row >= 8 ? 12 : 0); }
    function at(x, y) {
        for (const e of elements)
            if (x >= xOf(e.col) && x < xOf(e.col) + cellW && y >= yOf(e.row) && y < yOf(e.row) + cellH)
                return e.z;
        return 0;
    }
    function walk(dx, dy) {
        const here = elements[chosenZ - 1];
        const next = elements.find(e => e.col === here.col + dx && e.row === here.row + dy);
        if (!next)
            return false;
        chosenZ = next.z;
        return true;
    }
    Keys.onPressed: event => {
        const step = { [Qt.Key_Left]: [-1, 0], [Qt.Key_Right]: [1, 0], [Qt.Key_Up]: [0, -1], [Qt.Key_Down]: [0, 1] }[event.key];
        // At the table's edge the arrow isn't taken, so it goes on to the panel's own navigation.
        if (step && walk(step[0], step[1]))
            event.accepted = true;
    }
    readonly property var tone: ({ alkali: 0.9, alkaline: 0.72, transition: 0.32, post: 0.45, metalloid: 0.6, nonmetal: 0.8, halogen: 0.66, noble: 1, lanthanide: 0.24, actinide: 0.18 })
    property bool opened: false
    Component.onCompleted: opened = true
    Cue { id: sweep; name: "codex.sweep"; scope: root; on: root.opened && Motion.driving; enter: Motion.scaled(800); exit: 0; easing: Easing.Linear }
    onWidthChanged: table.requestPaint()
    onHeightChanged: table.requestPaint()
    Connections { target: sweep; function onValueChanged() { if (Motion.driving) table.requestPaint(); } }
    Canvas {
        id: table
        anchors.fill: parent
        onPaint: {
            const c = getContext("2d"), reached = Motion.driving ? sweep.value * 128 : 200;
            c.reset();
            c.textBaseline = "alphabetic";
            for (const e of root.elements) {
                const x = root.xOf(e.col), y = root.yOf(e.row), w = root.cellW, h = root.cellH;
                const fresh = Math.max(0, Math.min(1, (reached - e.z) / 10));
                if (fresh <= 0)
                    continue;
                c.globalAlpha = fresh;
                c.fillStyle = Qt.alpha(Design.ink, 0.04 + 0.13 * root.tone[e.kind]);
                c.fillRect(x, y, w, h);
                c.fillStyle = Design.warm;
                c.fillRect(x, y, 2, h * root.tone[e.kind]);
                c.fillStyle = Design.muted;
                c.textAlign = "left";
                c.font = Design.caption - 2 + "px '" + Design.mono + "'";
                c.fillText(String(e.z), x + 5, y + 11);
                c.textAlign = "center";
                if (w >= 46) {
                    c.fillStyle = Design.muted;
                    c.font = Design.caption - 3 + "px '" + Design.mono + "'";
                    c.fillText(e.name.length > 11 ? e.name.slice(0, 10) + "." : e.name, x + w / 2, y + h - 5);
                }
            }
            c.globalAlpha = 1;
        }
    }
    // The symbols are real text: Canvas falls back to a tiny default font if it can't resolve a family.
    Repeater {
        model: root.elements
        FText {
            required property var modelData
            x: root.xOf(modelData.col)
            y: root.yOf(modelData.row) + root.cellH * 0.2
            width: root.cellW
            height: root.cellH * 0.55
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: modelData.symbol
            headline: true
            sheared: false
            font.pixelSize: Design.readout
            font.weight: Font.Black
            opacity: Motion.driving ? Math.max(0, Math.min(1, (sweep.value * 128 - modelData.z) / 10)) : 1
        }
    }
    // The chosen one and the one under the pointer; these move, the table doesn't repaint.
    Rectangle {
        x: root.xOf(root.chosen.col) - 1
        y: root.yOf(root.chosen.row) - 1
        width: root.cellW + 2
        height: root.cellH + 2
        color: "transparent"
        border.width: 2
        border.color: Design.accent
    }
    Rectangle {
        visible: root.hoveredZ > 0
        x: root.xOf(root.showing.col) - 1
        y: root.yOf(root.showing.row) - 1
        width: root.cellW + 2
        height: root.cellH + 2
        color: "transparent"
        border.width: 2
        border.color: Design.warm
    }
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.hoveredZ > 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
        onPositionChanged: mouse => root.hoveredZ = root.at(mouse.x, mouse.y)
        onExited: root.hoveredZ = 0
        onClicked: mouse => {
            const z = root.at(mouse.x, mouse.y);
            if (z > 0) {
                root.chosenZ = z;
                root.forceActiveFocus();
                Feedback.play("ui.switch");
            }
        }
    }
    // The gap at the top of the table, columns 3 to 12, rows 1 to 3.
    Item {
        id: plate
        x: root.xOf(3)
        y: 0
        width: root.xOf(13) - root.gap - x
        height: root.yOf(4) - root.gap
        clip: true
        FText {
            id: symbol
            x: -6
            anchors.verticalCenter: parent.verticalCenter
            text: root.showing.symbol
            headline: true
            sheared: false
            font.pixelSize: Math.round(parent.height * 1.05)   // scale: as tall as the gap in the table, cropped
            font.weight: Font.Black
            font.letterSpacing: -6
            color: Qt.alpha(Design.ink, 0.2)
        }
        Column {
            x: Math.max(96, symbol.width * 0.62)
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            FText { text: root.showing.name.toUpperCase(); headline: true; font.pixelSize: Design.readout; font.weight: Font.Black }
            FText { text: "Z " + root.showing.z + "  ·  " + root.showing.mass + " U"; technical: true; color: Design.accent }
            FText { text: root.showing.label; technical: true; color: Design.warm }
            FText { text: root.showing.shells.join(" · "); technical: true; color: Design.muted }
        }
        // The atom: still in Silent; in Overdrive the same drawing turns.
        Atom {
            id: staticAtom
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            height: parent.height
            width: height
            shells: root.showing.shells
            visible: !moving.item
        }
        IdleLoop { id: orbiting; scope: plate; name: "codex.atom"; period: 6000 }
        Stratum {
            id: moving
            name: "codex.atom"
            gpu: false
            scope: plate
            anchors.fill: staticAtom
            sourceComponent: Atom { shells: root.showing.shells; phase: orbiting.phase }
        }
    }
    component Atom: Canvas {
        property var shells: []
        property real phase: 0
        onShellsChanged: requestPaint()
        onPhaseChanged: requestPaint()
        onWidthChanged: requestPaint()
        onPaint: {
            const c = getContext("2d"), cx = width / 2, cy = height / 2, n = shells.length;
            c.reset();
            const outer = Math.min(width, height) / 2 - 5;
            for (let s = 0; s < n; s++) {
                const r = outer * (0.26 + 0.74 * (s + 1) / n);
                c.strokeStyle = Qt.alpha(Design.ink, 0.28);
                c.lineWidth = 1;
                c.beginPath();
                c.arc(cx, cy, r, 0, 2 * Math.PI);
                c.stroke();
                // Inner shells faster, as Kepler would have it.
                const turn = 2 * Math.PI * phase * Math.round(n + 1 - s);
                c.fillStyle = s === n - 1 ? Design.warm : Design.accent;
                for (let e = 0; e < shells[s]; e++) {
                    const a = 2 * Math.PI * e / shells[s] + turn + s;
                    c.beginPath();
                    c.arc(cx + r * Math.cos(a), cy + r * Math.sin(a), s === n - 1 ? 2.4 : 1.7, 0, 2 * Math.PI);
                    c.fill();
                }
            }
            c.fillStyle = Design.ink;
            c.beginPath();
            c.arc(cx, cy, outer * 0.13, 0, 2 * Math.PI);
            c.fill();
        }
    }
}
