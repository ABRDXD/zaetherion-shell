import qs.core.client
import qs.view.cues
import qs.view.ui
import QtQuick
import "Recorder.js" as R

// The graphics card's chart recorder (docs/OVERDRIVE.md §45; B's own idea), the Stratum `performance.recorder` under the
// record while GPU is the reading: a circular chart turning once a minute under a fixed stylus at the top; the outer
// trace is the card's busy share, the inner stepped one the clock level it has engaged, VRAM an arc on the rim; one
// revolution kept. A sleeping card is named asleep and never asked anything else (`telemetry.gpu`, once a second).
Item {
    id: root
    property CoreClient core: null
    // False only in tests, which call take() themselves.
    property bool autonomous: true
    property var last: null
    property var trace: []
    property real seconds: 0
    readonly property var main: R.cards(last).main
    opacity: Motion.drive

    Timer {
        interval: 1000
        repeat: true
        running: root.autonomous
        triggeredOnStart: true
        onTriggered: root.core?.request("telemetry.gpu", {}, (ok, result) => { if (ok && result && root) root.take(result); })
    }
    function take(s) {
        if (!s || !s.running)
            return;
        seconds += 1;
        last = s;
        trace = R.record(trace, seconds, R.cards(s).main);
        canvas.requestPaint();
    }

    Canvas {
        id: canvas
        anchors.fill: parent
        anchors.bottomMargin: 30
        renderTarget: Canvas.Image
        onPaint: {
            const ctx = getContext("2d");
            const w = width, h = height;
            ctx.clearRect(0, 0, w, h);
            const r = Math.min(w, h) / 2 - 4, cx = w / 2, cy = h / 2;
            if (r <= 10)
                return;
            const at = (a, rr) => [cx + Math.sin(a) * rr * r, cy - Math.cos(a) * rr * r];
            // The chart: rings at a quarter, a half, three quarters and full; a tick every five seconds.
            ctx.strokeStyle = Qt.alpha(Design.line, 0.9);
            ctx.lineWidth = 1;
            for (const k of [0.42, 0.555, 0.69, 0.825, 0.96]) {
                ctx.beginPath();
                ctx.arc(cx, cy, k * r, 0, 2 * Math.PI);
                ctx.stroke();
            }
            ctx.beginPath();
            for (let i = 0; i < 12; i++) {
                const a = R.angle(root.seconds - i * 5, root.seconds) + 2 * Math.PI * (root.seconds % 5) / 60;
                const p0 = at(a, 0.4), p1 = at(a, 0.98);
                ctx.moveTo(p0[0], p0[1]);
                ctx.lineTo(p1[0], p1[1]);
            }
            ctx.stroke();
            // VRAM: an arc on the rim, from the top, as full as the card's memory.
            const m = root.main;
            if (m && m.total > 0) {
                ctx.strokeStyle = Qt.alpha(Design.ink, 0.5);
                ctx.lineWidth = 3;
                ctx.beginPath();
                ctx.arc(cx, cy, r, -Math.PI / 2, -Math.PI / 2 + 2 * Math.PI * m.vram / m.total);
                ctx.stroke();
            }
            // The traces: busy outside, the clock level inside, stepped.
            const tr = root.trace;
            if (tr.length > 1) {
                ctx.strokeStyle = Design.accent;
                ctx.lineWidth = 1.5;
                ctx.beginPath();
                tr.forEach((e, i) => {
                    const p = at(R.angle(e.t, root.seconds), R.busyR(e.busy));
                    if (i === 0) ctx.moveTo(p[0], p[1]); else ctx.lineTo(p[0], p[1]);
                });
                ctx.stroke();
                ctx.strokeStyle = Qt.alpha(Design.ink, 0.8);
                ctx.lineWidth = 1;
                ctx.beginPath();
                tr.forEach((e, i) => {
                    const p = at(R.angle(e.t, root.seconds), R.levelR(e.level));
                    if (i === 0) {
                        ctx.moveTo(p[0], p[1]);
                    } else {
                        const q = at(R.angle(e.t, root.seconds), R.levelR(tr[i - 1].level));
                        ctx.lineTo(q[0], q[1]);
                        ctx.lineTo(p[0], p[1]);
                    }
                });
                ctx.stroke();
            }
            // The stylus, fixed at the top.
            ctx.strokeStyle = Design.muted;
            ctx.lineWidth = 1;
            ctx.beginPath();
            ctx.moveTo(cx, cy - 0.12 * r);
            ctx.lineTo(cx, cy - r - 4);
            ctx.stroke();
        }
    }
    FText {
        anchors.bottom: parent.bottom
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        maximumLineCount: 2
        visible: !!root.last
        text: R.caption(root.last)
        technical: true
        voice: "kernel"
        color: Design.faint
    }
}
