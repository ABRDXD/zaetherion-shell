import QtQuick
import qs.view.ui
import qs.view.cues
import qs.view.strata

Item {
    id: root
    property var history: []
    property real at: 0
    property real renderedAt: at
    onAtChanged: renderedAt = at
    Canvas {
        id: trace
        property color signalColor: Design.accent
        onSignalColorChanged: requestPaint()
        anchors.fill: parent
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        Connections { target: root; function onHistoryChanged() { trace.requestPaint(); } function onRenderedAtChanged() { trace.requestPaint(); } }
        onPaint: {
            const c = getContext("2d"); c.reset();
            const events = root.history;
            if (!events.length) return;
            const start = Math.max(events[0].at, root.renderedAt - 1800), end = Math.max(start + 60, root.renderedAt);
            const lane = addr => { let h = 0; for (let i = 0; i < addr.length; i++) h = (h * 31 + addr.charCodeAt(i)) >>> 0; h ^= h >>> 16; h = Math.imul(h, 0x45d9f3b); h ^= h >>> 16; return 8 + (h >>> 0) % Math.max(1, Math.floor(width - 16)); };
            c.strokeStyle = Design.accent; c.lineWidth = 1.4; c.beginPath();
            let x = lane(events[0].address);
            for (const e of events) if (e.at < start) x = lane(e.address);
            c.moveTo(x, 0);
            for (const e of events) {
                if (e.at < start) { x = lane(e.address); continue; }
                const y = Math.max(0, (e.at - start) / (end - start) * height);
                c.lineTo(x, y); x = lane(e.address); c.lineTo(x, y);
            }
            c.lineTo(x, height); c.stroke();
        }
    }
    Stratum {
        anchors.fill: parent; name: "genealogy-seismograph"; gpu: false; scope: root
        sourceComponent: Component {
            Item {
                id: liveTrace
                IdleLoop { id: sweep; name: "genealogy.trace"; scope: liveTrace; period: 6000 }
                Rectangle {
                    anchors.bottom: parent.bottom; width: parent.width; height: 2
                    color: Design.accent; opacity: sweep.level * (0.3 + sweep.phase * 0.4)
                }
                // Time is information, sampled only in the live stratum. Silent keeps its opening snapshot.
                Timer { interval: 1000; repeat: true; running: Motion.engaged && Motion.seen; onTriggered: root.renderedAt = Date.now() / 1000 }
            }
        }
    }
}
