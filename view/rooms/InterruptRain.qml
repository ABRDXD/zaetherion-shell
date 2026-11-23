import qs.core.client
import qs.view.cues
import qs.view.ui
import QtQuick
import QtQuick.Shapes

// Interrupt rainfall (atlas #17, docs/OVERDRIVE.md §31): in Overdrive, Performance's hardware interrupts fall as sparse
// ticks striking one baseline, more as the machine is interrupted more (the logarithm of the rate), coloured by where
// they come from: the GPU in the accent, the network in the ink, the disk warm, timers and the processors' own calls
// faint. A class suddenly running at three times its own average leaves an impact crater in the line that stays for
// eight seconds. The core samples `/proc/interrupts` only while this exists (core/telemetry.py).
Item {
    id: root
    property CoreClient core: null
    readonly property real lineY: height - 8
    property var drops: []      // [{x, kind, born}]
    property var craters: []    // [{x, kind, born}]
    property double clock: 0
    property var last: null
    readonly property var inks: ({ gpu: Design.accent, net: Design.ink, disk: Design.calendarAccent, timer: Design.faint,
                                   ipi: Design.faint, input: Design.muted, usb: Design.muted, other: Design.line })
    Timer {
        interval: 1000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.core?.request("telemetry.sample", {}, (ok, result) => { if (ok && result && root) root.rain(result); })
    }
    // One sample: a few drops for the rate, by class, and a crater for each spike.
    function rain(s) {
        last = s;
        if (!s.running || !s.rain)
            return;
        const total = Math.max(0, s.total || 0), n = Math.min(14, Math.round(Math.log2(1 + total / 150)));
        const weights = s.rain.filter(r => r.rate > 0);
        const sum = weights.reduce((a, r) => a + Math.log2(1 + r.rate), 0);
        const fresh = [];
        for (let i = 0; i < n && sum > 0; i++) {
            let pick = Math.random() * sum, kind = weights[0].kind;
            for (const r of weights) { pick -= Math.log2(1 + r.rate); if (pick <= 0) { kind = r.kind; break; } }
            fresh.push({ x: Math.random() * width, kind: kind, born: clock + Math.random() * 0.9 });
        }
        drops = [...drops.filter(d => clock - d.born < 1.4), ...fresh];
        craters = [...craters.filter(c => clock - c.born < 8), ...(s.spikes || []).map(k => ({ x: 20 + Math.random() * (width - 40), kind: k, born: clock }))];
    }
    FrameAnimation {
        id: frames
        running: Motion.engaged && (root.drops.length > 0 || root.craters.length > 0)
        onTriggered: root.clock += frameTime * Motion.drive
    }
    Activity { name: "idle.performance.rain"; running: frames.running }
    // The craters fill 6 px over eight seconds: the line follows an 8 Hz clock, so its path (CurveRenderer) isn't
    // rebuilt on every frame while one fills.
    readonly property int craterTick: Math.floor(clock * 8)
    // The baseline, dented where a spike struck.
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        opacity: Motion.drive
        ShapePath {
            strokeColor: Design.line
            strokeWidth: 1
            fillColor: "transparent"
            PathPolyline {
                path: {
                    const pts = [Qt.point(0, root.lineY)];
                    for (const c of root.craters.slice().sort((a, b) => a.x - b.x)) {
                        const depth = 6 * Math.max(0, 1 - (root.craterTick / 8 - c.born) / 8);
                        pts.push(Qt.point(c.x - 7, root.lineY), Qt.point(c.x, root.lineY + depth), Qt.point(c.x + 7, root.lineY));
                    }
                    pts.push(Qt.point(root.width, root.lineY));
                    return pts;
                }
            }
        }
    }
    Repeater {
        model: root.drops
        Rectangle {
            required property var modelData
            readonly property real age: root.clock - modelData.born
            visible: age >= 0
            x: modelData.x
            width: 1
            height: 7
            // It falls 14 px in 0.2 s onto the line, then fades where it struck.
            y: root.lineY - height - 14 * Math.max(0, 1 - age / 0.2)
            color: root.inks[modelData.kind] ?? Design.line
            opacity: Motion.drive * (age < 0.2 ? 1 : Math.max(0, 1 - (age - 0.2) / 1.2))
        }
    }
    FText {
        anchors.right: parent.right
        y: root.lineY - implicitHeight - 4
        visible: !!root.last?.running
        text: "IRQ " + Math.round(root.last?.total ?? 0) + "/S" + ((root.last?.spikes ?? []).length ? " · " + root.last.spikes.join(" ").toUpperCase() : "")
        technical: true
        font.pixelSize: 9   // scale: the rain's figures
        color: Design.faint
        opacity: Motion.drive
        voice: "kernel"
    }
}
