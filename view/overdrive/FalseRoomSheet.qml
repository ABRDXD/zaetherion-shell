import qs.view.cues
import qs.view.ui
import QtQuick
import "FalseRoom.js" as F

// Inside the False Room (docs/OVERDRIVE_IDEAS.md W1, docs/OVERDRIVE.md §53): no controls, only a geometric
// reconstruction of metadata about past sessions, drawn once on entry (FalseRoom.js, reconstruct): a spoke per room,
// as long as the log of the time spent there, ticked once per visit; the hours of the day the rooms were used in, as
// a ring of bars; the last hops as a path between the spokes' tips, each stop stamped with its minute. Beneath it the
// machine now, in classes only. Room ids, counts and times: never anything a room holds. Esc or a click leaves, and
// the room is gone until a different set of conditions arrives.
Item {
    id: root
    property var rooms: []
    property var names: ({})
    property var journey: null
    property int devices: 0
    property string pressure: "—"
    property string signature: ""
    signal exited
    readonly property var model: F.reconstruct(rooms, journey, Math.min(width, height - 90))

    Rectangle {
        anchors.fill: parent
        color: Design.background
        opacity: 0.97
    }
    MouseArea {
        anchors.fill: parent
        onClicked: root.exited()
    }
    FText {
        x: 28
        y: 22
        text: "−1"
        headline: true
        font.pixelSize: Design.headline
        font.weight: Font.Black
        color: Design.accent
    }
    FText {
        x: 28
        y: 22 + Design.headline + 4
        text: "UNSURVEYED / A RECONSTRUCTION OF THE SESSIONS BEFORE THIS ONE"
        technical: true
        color: Design.muted
    }
    Canvas {
        id: plate
        readonly property real side: Math.min(root.width, root.height - 90)
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 46
        width: side
        height: side
        renderStrategy: Canvas.Immediate
        onPaint: {
            const g = getContext("2d"), m = root.model, c = side / 2;
            g.reset();
            g.translate(c, c);
            g.lineWidth = 1;
            // The day: twenty-four bars on a ring, midnight at the top.
            g.strokeStyle = Qt.alpha(Design.faint, 0.8);
            g.beginPath();
            g.arc(0, 0, side * 0.36, 0, 2 * Math.PI);
            g.stroke();
            g.strokeStyle = Design.warm;
            g.lineWidth = 3;
            for (const b of m.ring) {
                if (b.x0 === b.x1 && b.y0 === b.y1) continue;
                g.beginPath(); g.moveTo(b.x0, b.y0); g.lineTo(b.x1, b.y1); g.stroke();
            }
            g.lineWidth = 1;
            // The spokes, and a tick across each per visit.
            for (const s of m.spokes) {
                g.strokeStyle = Design.ink;
                g.beginPath(); g.moveTo(0, 0); g.lineTo(s.x, s.y); g.stroke();
                const nx = -Math.sin(s.angle) * 3, ny = Math.cos(s.angle) * 3;
                g.strokeStyle = Design.accent;
                for (const t of s.ticks) {
                    g.beginPath(); g.moveTo(t.x - nx, t.y - ny); g.lineTo(t.x + nx, t.y + ny); g.stroke();
                }
            }
            // The last hops, tip to tip.
            g.strokeStyle = Qt.alpha(Design.danger, 0.85);
            g.beginPath();
            m.path.forEach((p, i) => i === 0 ? g.moveTo(p.x, p.y) : g.lineTo(p.x, p.y));
            g.stroke();
            g.fillStyle = Design.danger;
            for (const p of m.path) g.fillRect(p.x - 1.5, p.y - 1.5, 3, 3);
        }
        Component.onCompleted: requestPaint()
        onSideChanged: requestPaint()
    }
    // The rooms' numbers at their spokes' ends, and the path's stamps.
    Repeater {
        model: root.model.spokes
        FText {
            required property var modelData
            x: plate.x + plate.side / 2 + modelData.x * 1.12 - implicitWidth / 2
            y: plate.y + plate.side / 2 + modelData.y * 1.12 - implicitHeight / 2
            text: String(modelData.index).padStart(2, "0") + " " + (root.names[modelData.id] ?? "")
            technical: true
            color: Design.muted
        }
    }
    Repeater {
        model: root.model.path
        FText {
            required property var modelData
            required property int index
            x: plate.x + plate.side / 2 + modelData.x + 6
            y: plate.y + plate.side / 2 + modelData.y + 2 + (index % 3) * 10
            text: modelData.stamp
            technical: true
            color: Qt.alpha(Design.danger, 0.9)
        }
    }
    FText {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: 22
        text: "DEVICES " + root.devices + "  ·  PRESSURE " + root.pressure + "  ·  CONDITIONS " + root.signature
        technical: true
        color: Design.muted
    }
    FText {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 22
        text: "NO CONTROLS · ESC"
        technical: true
        color: Design.faint
    }
}
