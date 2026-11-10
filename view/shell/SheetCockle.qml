import qs.view.cues
import qs.view.ui
import QtQuick
import "../ui/Paper.js" as P

// Cockled paper (docs/OVERDRIVE.md §47; B's own idea), the Stratum `sheet.cockle` on the room's sheet, under the room, in
// Overdrive: the sheet takes the processor's heat with a two-minute thermal mass and, from 50 °C, cockles: faint ripples
// at the house angle, light and dark, and a swell that moves the sheet's register marks out (RoomSheet reads `swell`).
// The core reads the processor's sensor only while this asks (`telemetry.thermal`, every 5 s).
Item {
    id: root
    property var core: null
    // False only in tests, which call take() themselves.
    property bool autonomous: true
    property real heat: NaN
    readonly property real cockle: Number.isFinite(heat) ? P.cockle(heat) : 0
    readonly property real swell: P.swell(cockle) * Motion.drive
    opacity: Motion.drive
    onCockleChanged: canvas.requestPaint()
    Timer {
        interval: 5000
        repeat: true
        running: root.autonomous && !!root.core
        triggeredOnStart: true
        onTriggered: root.core.request("telemetry.thermal", {}, (ok, result) => { if (ok && result && root) root.take(result, Date.now()); })
    }
    function take(r, now) {
        if (!r || !r.running)
            return;
        heat = P.warm(r.temp, now);
    }
    Canvas {
        id: canvas
        anchors.fill: parent
        renderTarget: Canvas.Image
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onAvailableChanged: if (available) requestPaint()
        onPaint: {
            const ctx = getContext("2d");
            const w = width, h = height, period = 90;
            ctx.clearRect(0, 0, w, h);
            const lean = h * Math.abs(Design.shear);
            for (const b of P.ripples(root.cockle, w + lean, period)) {
                ctx.fillStyle = b.light ? Qt.rgba(1, 1, 1, b.alpha) : Qt.rgba(0, 0, 0, b.alpha * 1.4);
                const x = b.offset - lean;
                ctx.beginPath();
                ctx.moveTo(x, h);
                ctx.lineTo(x + period / 2, h);
                ctx.lineTo(x + period / 2 + lean, 0);
                ctx.lineTo(x + lean, 0);
                ctx.closePath();
                ctx.fill();
            }
        }
    }
}
