import qs.core.client
import qs.view.cues
import QtQuick

// The network letterpress (atlas #73, docs/OVERDRIVE.md §31): in Overdrive, Devices' network plane presses its name
// into the paper. Bytes coming in deboss it (pressed in), bytes going out emboss it (raised), as deep as the traffic
// (the logarithm of the bytes a second); after a burst the impression holds for three seconds and then resets at once,
// no fading. This reads the core's counters (`telemetry.sample`, core/telemetry.py) once a second while it exists; the
// plane binds `press` (−1 deboss … 1 emboss). It draws nothing itself (an Item only so a Stratum can load it).
Item {
    id: root
    property CoreClient core: null
    property real press: 0
    property double heldUntil: 0
    Timer {
        interval: 1000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.core?.request("telemetry.sample", {}, (ok, result) => { if (ok && result && root) root.take(result); })
    }
    function depth(bytes) {
        return Math.max(0, Math.min(1, Math.log10(1 + bytes / 1000) / 3));
    }
    function take(s) {
        const now = Date.now(), rx = s.net?.rx ?? 0, tx = s.net?.tx ?? 0;
        const p = rx >= tx ? -depth(rx) : depth(tx);
        if (Math.abs(p) >= 0.05 && Math.abs(p) >= Math.abs(press) * 0.8) {
            press = p;
            heldUntil = now + 3000;
        } else if (now >= heldUntil) {
            press = 0;
        }
    }
}
