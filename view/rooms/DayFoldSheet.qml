import qs.view.ui
import QtQuick
import "DayFold.js" as Fold
import "DayTime.js" as T

// Home's sheet, folded by the day (docs/OVERDRIVE.md §36; atlas #9), the Stratum `home.fold` laid over Home in
// Overdrive. Each time it is made (each opening of Home in Overdrive) it presses a crease where the day is, placed as
// the day ruler places the hour; the sheet keeps the day's creases (Fold.kept, for the session; a new day is a new
// sheet), the older relaxed. The newest crease splits off the past, folded under and in shade; the next solar event is
// a fold not yet made (dashed), past which the next plane tilts to the light. Drawn once, on opening: nothing moves.
Item {
    id: root
    // Today's sunrise and sunset (local hours; NaN with no sky), and the moment of opening (a Date; tests set it).
    property real rise: NaN
    property real set: NaN
    property date opened: new Date()
    // Where the day ruler lies across the sheet (its x and width as shares of this width), so a crease stands right
    // above its hour; the whole width when there is no ruler.
    property real from: 0
    property real span: 1
    // False only in tests, which call open() themselves.
    property bool autonomous: true
    property var sheet: null
    readonly property real hour: opened.getHours() + opened.getMinutes() / 60
    readonly property real noon: Number.isFinite(rise) && Number.isFinite(set) ? (rise + set) / 2 : NaN
    readonly property var coming: Fold.next(hour, rise, noon, set)
    readonly property var folds: Fold.folds(sheet)
    function place(h) { return from + span * T.x(h, rise, set); }
    readonly property real nowX: place(hour)
    readonly property real nextX: coming ? (coming.tomorrow ? from + span : place(coming.h)) : -1

    function clock(h) {
        const m = Math.round(h * 60) % 1440;
        return String(Math.floor(m / 60)).padStart(2, "0") + ":" + String(m % 60).padStart(2, "0");
    }
    function open() {
        Fold.kept.sheet = Fold.press(Fold.kept.sheet, Qt.formatDate(opened, "yyyy-MM-dd"), hour, nowX);
        sheet = Fold.kept.sheet;
        canvas.requestPaint();
    }
    Component.onCompleted: if (autonomous) open()

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
            if (!root.sheet || w <= 0)
                return;
            // The three planes: the past folded under, the next tilted to the light.
            const nx = root.nowX * w;
            const past = ctx.createLinearGradient(0, 0, nx, 0);
            past.addColorStop(0, "rgba(0, 0, 0, 0.03)");
            past.addColorStop(1, "rgba(0, 0, 0, 0.10)");
            ctx.fillStyle = past;
            ctx.fillRect(0, 0, nx, h);
            if (root.nextX > root.nowX) {
                const fx = root.nextX * w;
                const ahead = ctx.createLinearGradient(fx, 0, w, 0);
                ahead.addColorStop(0, "rgba(255, 255, 255, 0.06)");
                ahead.addColorStop(1, "rgba(255, 255, 255, 0.015)");
                ctx.fillStyle = ahead;
                ctx.fillRect(fx, 0, w - fx, h);
            }
            // The creases: a shadow on the side folded away, a highlight on the side towards the light, a hairline.
            for (const f of root.folds) {
                const x = Math.round(f.x * w) + 0.5, d = f.depth;
                const dark = f.valley ? -1 : 1;
                const shade = ctx.createLinearGradient(x + dark * 26, 0, x, 0);
                shade.addColorStop(0, "rgba(0, 0, 0, 0)");
                shade.addColorStop(1, "rgba(0, 0, 0, " + (0.16 * d).toFixed(3) + ")");
                ctx.fillStyle = shade;
                ctx.fillRect(Math.min(x, x + dark * 26), 0, 26, h);
                const lit = ctx.createLinearGradient(x, 0, x - dark * 10, 0);
                lit.addColorStop(0, "rgba(255, 255, 255, " + (0.10 * d).toFixed(3) + ")");
                lit.addColorStop(1, "rgba(255, 255, 255, 0)");
                ctx.fillStyle = lit;
                ctx.fillRect(Math.min(x, x - dark * 10), 0, 10, h);
                ctx.fillStyle = "rgba(0, 0, 0, " + (0.22 * d).toFixed(3) + ")";
                ctx.fillRect(x - 0.5, 0, 1, h);
            }
            // The fold not yet made.
            if (root.nextX > root.nowX && root.nextX < root.from + root.span) {
                const fx = Math.round(root.nextX * w) + 0.5;
                ctx.strokeStyle = Qt.alpha(Design.faint, 0.55);
                ctx.lineWidth = 1;
                ctx.beginPath();
                for (let y = 0; y < h; y += 9) {
                    ctx.moveTo(fx, y);
                    ctx.lineTo(fx, Math.min(h, y + 4));
                }
                ctx.stroke();
            }
        }
    }
    // The newest crease's time, and the next fold's, at the top of each line.
    // The crease's label stands on the past's side of it, the fold's on the future's, so they never meet.
    FText {
        visible: root.folds.length > 0
        x: Math.max(0, Math.round(root.nowX * root.width) - width - 4)
        y: 2
        text: "PRESSED " + root.clock(root.hour)
        technical: true
        color: Design.faint
    }
    FText {
        visible: root.nextX > root.nowX && root.nextX < root.from + root.span
        x: Math.round(root.nextX * root.width) + 4
        y: 2
        text: "FOLD " + (root.coming ? root.clock(root.coming.h) + " · " + root.coming.name : "")
        technical: true
        color: Design.faint
    }
}
