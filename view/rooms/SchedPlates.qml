import qs.core.client
import qs.view.cues
import qs.view.ui
import QtQuick
import "Plates.js" as P

// The scheduler's ground under Performance's trace (docs/OVERDRIVE.md §37; atlas #15, #72), the Stratum
// `performance.plates`: each core a plate of a power diagram, its faults pushed out by its load, slipping under runnable
// pressure, with the faults' recent positions left as scarps; and the context switches woven across as two families of
// threads, voluntary at the house angle, involuntary opening away as preemption grows. The core reads `/proc/stat` and
// the processes' switch counters only while this exists (core/telemetry.py, `telemetry.sched`). Redrawn once a sample.
Item {
    id: root
    property CoreClient core: null
    // False only in tests, which call take() themselves.
    property bool autonomous: true
    property var last: null
    // The cores' loads, eased from sample to sample so the faults migrate rather than jump.
    property var loads: []
    property var polys: []
    property var scarps: []
    property real phaseV: 0
    property real phaseI: 0
    property double seconds: 0
    readonly property real stress: last ? P.stress(last.runnable ?? 0, loads.length) : 0
    readonly property var weave: last ? P.weave(last.voluntary ?? 0, last.involuntary ?? 0) : P.weave(0, 0)
    // The busiest core, whose plate is labelled (the largest by area can be another, cut by the record's edge).
    readonly property int lead: polys.length ? loads.reduce((best, l, i) => l > loads[best] ? i : best, 0) : -1
    opacity: Motion.drive

    Timer {
        interval: 1000
        repeat: true
        running: root.autonomous
        triggeredOnStart: true
        onTriggered: root.core?.request("telemetry.sched", {}, (ok, result) => { if (ok && result && root) root.take(result); })
    }
    // One sample: ease the loads, rebuild the plates, keep a scarp every 4 s, slide the threads.
    function take(s) {
        seconds += 1;
        if (!s || !s.running)
            return;
        last = s;
        const cores = s.cores ?? [];
        if (cores.length) {
            loads = loads.length === cores.length ? cores.map((c, i) => loads[i] + (c - loads[i]) * 0.5) : cores.slice();
            const grid = P.seeds(loads.length, width, height);
            polys = P.cells(grid.seeds, P.weights(loads, grid.cell), width, height);
            scarps = P.scarp(scarps, polys, seconds, 4);
        }
        phaseV = (phaseV + Math.min(0.5, (s.voluntary ?? 0) / 20000)) % 1;
        phaseI = (phaseI + Math.min(0.5, (s.involuntary ?? 0) / 2000)) % 1;
        canvas.requestPaint();
    }
    onWidthChanged: { scarps = []; polys = []; }
    onHeightChanged: { scarps = []; polys = []; }

    Canvas {
        id: canvas
        anchors.fill: parent
        renderTarget: Canvas.Image
        onPaint: {
            const ctx = getContext("2d");
            const w = width, h = height;
            ctx.clearRect(0, 0, w, h);
            const line = (segs, color, width) => {
                ctx.strokeStyle = color;
                ctx.lineWidth = width;
                ctx.beginPath();
                for (const s of segs) { ctx.moveTo(s[0], s[1]); ctx.lineTo(s[2], s[3]); }
                ctx.stroke();
            };
            // The weave, under everything.
            const wv = root.weave;
            line(P.threads(wv.voluntary, wv.angleV, root.phaseV, w, h), Qt.alpha(Design.faint, 0.22), 1);
            line(P.threads(wv.involuntary, wv.angleI, root.phaseI, w, h), Qt.alpha(Design.accent, 0.28), 1);
            // A plate's edges, but not those lying on the record's own border: only faults between plates.
            const rim = (p, q) => (Math.abs(p.x) < 0.5 && Math.abs(q.x) < 0.5) || (Math.abs(p.x - w) < 0.5 && Math.abs(q.x - w) < 0.5)
                || (Math.abs(p.y) < 0.5 && Math.abs(q.y) < 0.5) || (Math.abs(p.y - h) < 0.5 && Math.abs(q.y - h) < 0.5);
            const outline = (poly, dx, dy) => {
                for (let i = 0; i < poly.length; i++) {
                    const p = poly[i], q = poly[(i + 1) % poly.length];
                    if (rim(p, q)) continue;
                    ctx.moveTo(p.x + dx, p.y + dy);
                    ctx.lineTo(q.x + dx, q.y + dy);
                }
            };
            // The scarps, oldest faintest.
            root.scarps.slice(0, -1).forEach((s, k, all) => {
                ctx.strokeStyle = Qt.alpha(Design.line, 0.08 + 0.22 * (k + 1) / all.length);
                ctx.lineWidth = 1;
                ctx.beginPath();
                for (const p of s.polys) outline(p, 0, 0);
                ctx.stroke();
            });
            // The faults now: under stress, each drawn twice, its sides thrown apart along the house angle.
            const t = P.throwOf(root.stress);
            const ink = root.stress > 0.5 ? Design.accent : Design.muted;
            ctx.strokeStyle = Qt.alpha(ink, 0.75);
            ctx.lineWidth = 1;
            ctx.beginPath();
            for (const p of root.polys) outline(p, 0, 0);
            ctx.stroke();
            if (t > 0) {
                ctx.strokeStyle = Qt.alpha(ink, 0.45);
                ctx.beginPath();
                for (const p of root.polys) outline(p, t * 0.208, -t * 0.978);
                ctx.stroke();
            }
        }
    }
    // The busiest core's plate: which core, and its load.
    FText {
        readonly property var at: root.lead >= 0 ? P.centroid(root.polys[root.lead]) : ({ x: 0, y: 0 })
        visible: root.lead >= 0
        x: Math.max(0, Math.min(root.width - width, at.x - width / 2))
        y: Math.max(0, Math.min(root.height - height, at.y - height / 2))
        text: "CPU " + root.lead + " · " + Math.round(100 * (root.loads[root.lead] ?? 0)) + "%"
        technical: true
        voice: "kernel"
        color: Design.faint
    }
    // The scheduler's own figures, in the kernel's voice.
    FText {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        visible: !!root.last
        text: "RUNNABLE " + (root.last?.runnable ?? 0) + " · CSW " + (root.last?.voluntary ?? 0) + " / " + (root.last?.involuntary ?? 0) + " PREEMPTED"
        technical: true
        voice: "kernel"
        color: root.stress > 0.5 ? Design.accent : Design.faint
    }
}
