import qs.core.client
import qs.view.cues
import qs.view.ui
import QtQuick
import "Silt.js" as S

// The swap as silt (docs/OVERDRIVE.md §46; B's own idea), the Stratum `performance.silt` under the record while SWAP is
// the reading: pages swapped out fall as grains and settle on a bed as deep as the swap in use; pages swapped in lift
// grains off it and up out of the record; the bed is laid in bands, a minute each, compacting darker as they age. The
// core reads `/proc/vmstat` and `/proc/meminfo` only while this asks (`telemetry.swap`, once a second). Grains move only
// while they're in flight.
Item {
    id: root
    property CoreClient core: null
    // False only in tests, which call take() themselves.
    property bool autonomous: true
    property var last: null
    property real seconds: 0
    property real clock: 0
    property var flying: []
    property var bands: []
    readonly property real bed: last ? S.depth(last.used, last.total) : 0
    opacity: Motion.drive

    Timer {
        interval: 1000
        repeat: true
        running: root.autonomous
        triggeredOnStart: true
        onTriggered: root.core?.request("telemetry.swap", {}, (ok, result) => { if (ok && result && root) root.take(result); })
    }
    function take(s) {
        if (!s || !s.running)
            return;
        seconds += 1;
        last = s;
        bands = S.lay(bands, seconds, S.depth(s.used, s.total));
        const fresh = [];
        for (let i = 0; i < S.grains(s.out); i++)
            fresh.push({ x: Math.random(), born: clock + Math.random() * 0.8, up: false });
        for (let i = 0; i < S.grains(s.in); i++)
            fresh.push({ x: Math.random(), born: clock + Math.random() * 0.8, up: true });
        flying = flying.filter(g => S.place(g, clock, bed).alive).concat(fresh);
        canvas.requestPaint();
    }
    // The grains, repainted at about 30 frames a second (a canvas paint is JavaScript; the tide does the same at 20).
    property real since: 0
    FrameAnimation {
        id: frames
        running: Motion.engaged && root.flying.length > 0
        onTriggered: {
            root.clock += frameTime * Motion.drive;
            root.since += frameTime;
            if (root.since < 1 / 30)
                return;
            root.since = 0;
            canvas.requestPaint();
            if (root.flying.every(g => !S.place(g, root.clock, root.bed).alive))
                root.flying = [];
        }
    }
    Activity { name: "idle.performance.silt"; running: frames.running }

    Canvas {
        id: canvas
        anchors.fill: parent
        renderTarget: Canvas.Image
        onPaint: {
            const ctx = getContext("2d");
            const w = width, h = height;
            ctx.clearRect(0, 0, w, h);
            // The bed, band by band: each from the depth it reached, the older ones darker beneath.
            const n = root.bands.length;
            root.bands.forEach((b, i) => {
                const top = h - (i === n - 1 ? root.bed : b.h) * h;
                const below = i > 0 ? h - root.bands[i - 1].h * h : h;
                ctx.fillStyle = Qt.alpha(Design.muted, S.compaction(i, n));
                ctx.fillRect(0, Math.min(top, below), w, Math.max(1, Math.abs(below - top)));
            });
            if (root.bed > 0) {
                ctx.fillStyle = Qt.alpha(Design.ink, 0.5);
                ctx.fillRect(0, Math.round(h - root.bed * h), w, 1);
            }
            // The grains in flight.
            for (const g of root.flying) {
                const p = S.place(g, root.clock, root.bed);
                if (!p.alive || p.y < 0)
                    continue;
                ctx.fillStyle = g.up ? Design.accent : Design.ink;
                ctx.fillRect(Math.round(p.x * (w - 3)), Math.round(p.y * h) - 3, 3, 3);
            }
        }
    }
    FText {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        visible: !!root.last
        text: "OUT " + Math.round(root.last?.out ?? 0) + " · IN " + Math.round(root.last?.in ?? 0) + " PAGES/S"
        technical: true
        voice: "kernel"
        color: Design.faint
    }
}
