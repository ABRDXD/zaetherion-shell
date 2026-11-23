import qs.view.cues
import qs.view.ui
import QtQuick
import "Spectro.js" as S

// The process spectrograph (docs/OVERDRIVE.md §40; atlas #74), the Stratum `performance.spectrograph` under the
// record's trace while MEM is the reading: each process a vertical line at its lifetime class (x, the log of its age),
// as tall as its CPU share, as thick as its memory, notched once for each time it stopped and started again in the last
// minute. Forks spark at the left edge; an ended process's line stays as a ghost for five seconds. It reads the
// orrery's samples (`sample`, from OrreryField), so the core reads nothing more for it.
Item {
    id: root
    // The orrery's last sample: {running, bodies, forks, exits}.
    property var sample: null
    property var tracks: ({})
    property real seconds: 0
    property int sparks: 0
    readonly property var names: S.named(tracks, 4)
    opacity: Motion.drive
    onSampleChanged: take(sample)
    function take(s) {
        if (!s || !s.running)
            return;
        seconds += 1;
        tracks = S.track(tracks, s.bodies, seconds);
        sparks = Math.min(24, s.forks ?? 0);
        canvas.requestPaint();
    }

    Canvas {
        id: canvas
        anchors.fill: parent
        anchors.bottomMargin: 14
        renderTarget: Canvas.Image
        onPaint: {
            const ctx = getContext("2d");
            const w = width, h = height;
            ctx.clearRect(0, 0, w, h);
            // The lifetime classes, as faint verticals.
            ctx.fillStyle = Qt.alpha(Design.line, 0.6);
            for (const m of S.MARKS)
                ctx.fillRect(Math.round(S.ageX(m[0]) * (w - 8)) + 4, 0, 1, h);
            // The lines, ghosts first, heavier last.
            const ids = Object.keys(root.tracks).sort((a, b) => (root.tracks[b].gone ? 1 : 0) - (root.tracks[a].gone ? 1 : 0) || root.tracks[a].w - root.tracks[b].w);
            for (const id of ids) {
                const t = root.tracks[id];
                const x = Math.round(t.x * (w - 8)) + 4, top = h - Math.max(2, t.y * h);
                ctx.fillStyle = t.gone ? Qt.alpha(Design.faint, 0.35) : t.born || t.x < 0.12 ? Design.accent : Qt.alpha(Design.ink, 0.35 + 0.6 * t.y);
                ctx.fillRect(x - t.w / 2, top, t.w, h - top);
                // Interruptions: notches cut out of the line.
                for (const ny of S.notchYs(t.notches.length, h - top))
                    ctx.clearRect(x - t.w / 2 - 1, top + ny - 1, t.w + 2, 2);
            }
            // Forks since the last sample: sparks at the left edge.
            ctx.fillStyle = Design.accent;
            for (let i = 0; i < root.sparks; i++)
                ctx.fillRect(1 + (i % 3) * 2, h - 4 - Math.floor(i / 3) * 5, 1, 3);
        }
    }
    // The axis: the lifetime classes under the plate.
    Repeater {
        model: S.MARKS
        FText {
            required property var modelData
            x: Math.min(root.width - width, Math.max(0, Math.round(S.ageX(modelData[0]) * (root.width - 8)) + 4 - width / 2))
            y: root.height - height
            text: modelData[1]
            technical: true
            voice: "kernel"
            color: Design.faint
            font.pixelSize: Design.caption
        }
    }
    // The tallest lines, named (the process's own 15-character name).
    Repeater {
        model: root.names
        FText {
            required property var modelData
            readonly property var t: root.tracks[modelData] ?? ({ x: 0, y: 0 })
            x: Math.min(root.width - width, Math.round(t.x * (root.width - 8)) + 8)
            y: Math.max(0, (root.height - 14) * (1 - t.y) - 2)
            text: (t.name ?? "").toUpperCase()
            technical: true
            voice: "kernel"
            color: Design.muted
            font.pixelSize: Design.caption
        }
    }
}
