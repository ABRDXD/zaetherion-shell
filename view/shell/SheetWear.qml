import qs.view.cues
import qs.view.ui
import QtQuick
import "../ui/Paper.js" as P

// Handled paper (docs/OVERDRIVE.md §41; B's own idea), the Stratum `sheet.wear` on the room's sheet, under the room, in
// Overdrive: the sheet wears with the time you've spent in the room (the journey's decayed seconds): the corner you'd
// hold is thumbed (smudged in the ink), rust foxing gathers at the margins in the room's own places, and after twenty
// openings the upper outer corner is dog-eared, more with every doubling. Drawn when the room or its wear changes.
Item {
    id: root
    property string roomId: ""
    // The side the title's wedge stands on: the held corners are on the other side.
    property bool wedgeLeft: true
    // The journey ({seconds, visits}), or null.
    property var journey: null
    readonly property real worn: P.wear(journey?.seconds?.[roomId] ?? 0)
    readonly property int visits: journey?.visits?.[roomId] ?? 0
    readonly property int ear: P.dogEar(visits)
    opacity: Motion.drive
    onWornChanged: canvas.requestPaint()
    onEarChanged: canvas.requestPaint()
    onRoomIdChanged: canvas.requestPaint()

    Canvas {
        id: canvas
        anchors.fill: parent
        renderTarget: Canvas.Image
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onAvailableChanged: if (available) requestPaint()
        onPaint: {
            const ctx = getContext("2d");
            const w = width, h = height;
            ctx.clearRect(0, 0, w, h);
            if (w <= 0 || h <= 0)
                return;
            const outerX = root.wedgeLeft ? w : 0;
            // Thumbing: a soft smudge in the ink at the lower outer corner.
            const t = P.thumb(root.worn, w, h);
            if (t.alpha > 0.005) {
                const g = ctx.createRadialGradient(outerX, h, 0, outerX, h, t.reach);
                g.addColorStop(0, Qt.alpha(Design.ink, t.alpha));
                g.addColorStop(1, Qt.alpha(Design.ink, 0));
                ctx.fillStyle = g;
                ctx.fillRect(root.wedgeLeft ? w - t.reach : 0, h - t.reach, t.reach, t.reach);
            }
            // Foxing.
            for (const s of P.spots(root.roomId, w, h, root.worn)) {
                ctx.fillStyle = Qt.alpha(Design.warning, s.a);
                ctx.beginPath();
                ctx.ellipse(s.x - s.r, s.y - s.r * 0.8, 2 * s.r, 1.6 * s.r);
                ctx.fill();
            }
            // The dog-ear: the corner folded over, its flap and its crease.
            const e = root.ear;
            if (e > 0) {
                const sx = root.wedgeLeft ? -1 : 1;
                ctx.fillStyle = Design.background;
                ctx.beginPath();
                ctx.moveTo(outerX, 0);
                ctx.lineTo(outerX + sx * e, 0);
                ctx.lineTo(outerX, e);
                ctx.closePath();
                ctx.fill();
                ctx.fillStyle = Qt.tint(Design.surface, Qt.alpha(Design.ink, 0.08));
                ctx.beginPath();
                ctx.moveTo(outerX + sx * e, 0);
                ctx.lineTo(outerX + sx * e, e);
                ctx.lineTo(outerX, e);
                ctx.closePath();
                ctx.fill();
                ctx.strokeStyle = Qt.alpha(Design.line, 0.9);
                ctx.lineWidth = 1;
                ctx.beginPath();
                ctx.moveTo(outerX + sx * e, 0);
                ctx.lineTo(outerX, e);
                ctx.stroke();
            }
        }
    }
}
