import qs.view.cues
import QtQuick

// The cache palimpsest (atlas #71, docs/OVERDRIVE.md §19). Put inside a Text: in Overdrive, each value the text
// stops showing stays as a faint impression under the new one, a pixel or so out of register, fading by a half-life
// set by `pressure` (0–1, how full memory is): on a roomy machine the paper is clean in about three seconds; on a
// full one the old figures linger for up to a minute, layered, like a page that can't be erased. In Silent, and under
// reduced motion, it holds nothing and draws nothing.
Item {
    id: root
    readonly property Text target: parent as Text
    property real pressure: 0
    readonly property real halfLife: 1 + 60 * Math.pow(Math.max(0, Math.min(1, (pressure - 0.3) / 0.7)), 2)
    property var ghosts: []
    property string last: target?.text ?? ""
    property real clock: 0
    property int stamped: 0
    z: -1
    width: target?.width ?? 0
    height: target?.height ?? 0
    Connections {
        target: root.target
        function onTextChanged() { root.impress(); }
    }
    function impress() {
        const now = target.text;
        if (!Motion.engaged || Motion.reduced) {
            ghosts = [];
            last = now;
            return;
        }
        if (last !== "" && last !== now) {
            // Each impression lands a little off: alternating sides, never twice in the same place.
            const k = stamped++;
            const kept = ghosts.filter(g => 0.4 * Math.pow(0.5, (clock - g.born) / halfLife) > 0.05).slice(-5);
            ghosts = [...kept, { text: last, born: clock, dx: (k % 2 ? 1 : -1) * (0.6 + (k * 0.37) % 1.2), dy: ((k * 0.61) % 1.4) - 0.7 }];
        }
        last = now;
    }
    // Ages the impressions while there are any; nothing runs on a clean page.
    FrameAnimation {
        id: frames
        running: root.ghosts.length > 0 && Motion.engaged
        onTriggered: {
            root.clock += frameTime;
            if (root.ghosts.every(g => 0.4 * Math.pow(0.5, (root.clock - g.born) / root.halfLife) * Motion.drive <= 0.05))
                root.ghosts = [];
        }
    }
    Activity { name: "idle.palimpsest"; running: frames.running }
    Connections {
        target: Motion
        function onEngagedChanged() { if (!Motion.engaged) root.ghosts = []; }
    }
    Repeater {
        model: root.ghosts
        Text {
            required property var modelData
            x: modelData.dx
            y: modelData.dy
            width: root.width
            height: root.height
            text: modelData.text
            font: root.target.font
            horizontalAlignment: root.target.horizontalAlignment
            verticalAlignment: root.target.verticalAlignment
            elide: root.target.elide
            color: Design.faint
            opacity: 0.4 * Math.pow(0.5, (root.clock - modelData.born) / root.halfLife) * Motion.drive
        }
    }
}
