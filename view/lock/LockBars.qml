pragma ComponentBehavior: Bound
import QtQuick
import qs.view.ui

// The lock's visualiser (owner, 24 Nov: "the cava is BARELY VISIBLE"), after the previous shell's visualiser face: as many
// rounded bars as fit, rising from the band's top edge in the palette's accent, faint at rest and brighter with their
// level, fading at both ends. Passive: it draws the levels it is given (the host's spectrum), with no clock of its own.
Item {
    id: root
    property var levels: []
    property real unit: 1
    readonly property real barWidth: 7 * unit
    readonly property real gap: 4 * unit
    readonly property int count: Math.max(4, Math.min(200, Math.floor((width + gap) / (barWidth + gap))))
    readonly property real span: count * barWidth + (count - 1) * gap

    function level(i) {
        const n = levels.length;
        if (n === 0) return 0;
        const at = i * (n - 1) / Math.max(1, count - 1);
        const lo = Math.floor(at), t = at - lo;
        const a = Number(levels[lo]) || 0, b = Number(levels[Math.min(n - 1, lo + 1)]) || 0;
        return Math.max(0, Math.min(1, a + (b - a) * t));
    }
    function edge(i) {
        const d = Math.min(i, count - 1 - i) / Math.max(1, count * 0.12);
        return Math.min(1, d);
    }

    Repeater {
        model: root.count
        Rectangle {
            required property int index
            readonly property real value: root.level(index)
            x: (root.width - root.span) / 2 + index * (root.barWidth + root.gap)
            width: root.barWidth
            height: Math.max(3 * root.unit, value * root.height * 0.96)
            y: root.height - height
            radius: width * 0.35
            color: Design.accent
            opacity: (0.3 + 0.7 * value) * (0.25 + 0.75 * root.edge(index))
        }
    }
}
