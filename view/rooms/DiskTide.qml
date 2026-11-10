import qs.core.client
import qs.view.cues
import qs.view.ui
import QtQuick
import "Tide.js" as T

// The disk as a tide (docs/OVERDRIVE.md §44; B's own idea), the Stratum `performance.tide` under the record while DISK is
// the reading: the water stands as high as the disks are busy; reads run its waves in (leftwards), writes draw them out,
// as fast as the log of the bytes; a burst leaves a wrack line at its high-water mark for five minutes, and the session's
// highest water stays as the tideline. The core reads `/proc/diskstats` only while this asks (`telemetry.disk`, once a
// second; core/telemetry.py). The waves move while the engine runs; at rest nothing is drawn but the water's level.
Item {
    id: root
    property CoreClient core: null
    // False only in tests, which call take() themselves.
    property bool autonomous: true
    property var last: null
    property var state: T.step(null, 0, 0, 0)
    property real seconds: 0
    property real phase: 0
    readonly property real speed: last ? T.drift(last.read ?? 0, last.written ?? 0) : 0
    opacity: Motion.drive

    Timer {
        interval: 1000
        repeat: true
        running: root.autonomous
        triggeredOnStart: true
        onTriggered: root.core?.request("telemetry.disk", {}, (ok, result) => { if (ok && result && root) root.take(result, 1); })
    }
    function take(s, dt) {
        if (!s || !s.running)
            return;
        seconds += dt;
        last = s;
        state = T.step(state, s.busy ?? 0, dt, seconds);
        canvas.requestPaint();
    }
    // The waves, at about 20 frames a second while the engine runs.
    property real since: 0
    FrameAnimation {
        id: frames
        running: Motion.engaged && root.speed !== 0
        onTriggered: {
            root.phase += frameTime * root.speed * Motion.drive;
            root.since += frameTime;
            if (root.since >= 0.05) {
                root.since = 0;
                canvas.requestPaint();
            }
        }
    }
    Activity { name: "idle.performance.tide"; running: frames.running }
    function clock(at) {
        const d = new Date(Date.now() - (root.seconds - at) * 1000);
        return String(d.getHours()).padStart(2, "0") + ":" + String(d.getMinutes()).padStart(2, "0");
    }

    Canvas {
        id: canvas
        anchors.fill: parent
        renderTarget: Canvas.Image
        onPaint: {
            const ctx = getContext("2d");
            const w = width, h = height;
            ctx.clearRect(0, 0, w, h);
            const y = v => h - v * h;
            // The tideline: the session's highest water.
            if (root.state.high.h > 0.02) {
                ctx.fillStyle = Qt.alpha(Design.muted, 0.8);
                ctx.fillRect(0, Math.round(y(root.state.high.h)), w, 1);
            }
            // Wrack lines: dashed, fading over five minutes.
            for (const wk of root.state.wracks) {
                ctx.fillStyle = Qt.alpha(Design.faint, 0.7 * T.fade(wk, root.seconds));
                const wy = Math.round(y(wk.h));
                for (let x = 0; x < w; x += 7)
                    ctx.fillRect(x, wy, 3, 1);
            }
            // The water, its surface two travelling waves.
            const lv = root.state.level;
            if (lv > 0.003) {
                const amp = Math.min(6, 1 + 40 * lv) * Math.min(1, Math.abs(root.speed) / 10 + 0.3);
                ctx.beginPath();
                ctx.moveTo(0, h);
                for (let x = 0; x <= w; x += 4) {
                    const s = Math.sin((x + root.phase) / 37) * amp + Math.sin((x + root.phase * 1.7) / 13) * amp * 0.35;
                    ctx.lineTo(x, Math.min(h, y(lv) + s));
                }
                ctx.lineTo(w, h);
                ctx.closePath();
                ctx.fillStyle = Qt.alpha(Design.accent, 0.16);
                ctx.fill();
                ctx.strokeStyle = Qt.alpha(Design.accent, 0.7);
                ctx.lineWidth = 1;
                ctx.stroke();
            }
        }
    }
    FText {
        visible: root.state.high.h > 0.02
        anchors.right: parent.right
        y: Math.max(0, root.height - root.state.high.h * root.height - height - 2)
        text: "HW " + root.clock(root.state.high.at)
        technical: true
        color: Design.muted
    }
    FText {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        visible: !!root.last
        text: "READ " + root.rate(root.last?.read) + " · WRITE " + root.rate(root.last?.written) + " · BUSY " + Math.round(100 * (root.last?.busy ?? 0)) + "%"
        technical: true
        voice: "kernel"
        color: Design.faint
    }
    function rate(b) {
        const v = Math.max(0, b ?? 0);
        return v >= 1e6 ? (v / 1e6).toFixed(1) + " MB/S" : v >= 1e3 ? Math.round(v / 1e3) + " KB/S" : Math.round(v) + " B/S";
    }
}
