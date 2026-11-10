import qs.view.cues
import qs.view.ui
import QtQuick
import "MatchCut.js" as Cut

// Archive match cut (docs/OVERDRIVE_IDEAS.md #40, docs/OVERDRIVE.md §51): story and interface share one editing
// grammar. Leaving the archive in Overdrive, the archive goes in a hard cut, but one number survives it: the room you
// return to's own, found in an archive label still on screen. It holds still in the archive's type while the room
// appears around it, then its bounding box, in crop marks and leaving ghosts, glides into the room's number in the
// title wedge and hands over to it. The Shell finds the pivot and starts the cut; this only draws it.
Item {
    id: root
    // { x, y, w, h, size, text } in this item's coordinates: the pivot as the archive set it, and the room's number.
    property var from: null
    property var to: null
    property real u: 0
    readonly property bool running: cut.running
    readonly property real k: Cut.glide(u)
    readonly property var now: from && to ? Cut.box(from, to, k) : null
    visible: now !== null && cut.running
    opacity: Cut.fade(u) * Motion.drive

    // The pivot: in `archive`, the topmost single-line text on screen that holds `number` (MatchCut.js's find), as
    // a box in this item's coordinates. Clipped-away text (a note scrolled out of its list) doesn't count.
    function pivotIn(archive, number) {
        let best = null;
        const shown = item => {
            const p = item.mapToItem(archive, 0, 0), q = item.mapToItem(archive, item.width, item.height);
            if (p.y < 0 || q.y > archive.height || p.x < 0 || q.x > archive.width)
                return false;
            for (let a = item.parent; a && a !== archive; a = a.parent) {
                if (!a.clip)
                    continue;
                const ap = item.mapToItem(a, 0, 0);
                if (ap.y < 0 || ap.y + item.height > a.height || ap.x < 0 || ap.x + item.width > a.width)
                    return false;
            }
            return true;
        };
        const walk = item => {
            if (!item || !item.visible || item.opacity === 0)
                return;
            if (typeof item.text === "string" && item.lineCount === 1 && item.font !== undefined) {
                const run = Cut.find(item.text, number);
                if (run && shown(item)) {
                    metrics.font = item.font;
                    metrics.text = item.text.slice(0, run.at);
                    const lead = metrics.advanceWidth;
                    metrics.text = item.text.substr(run.at, run.length);
                    const w = metrics.advanceWidth;
                    const shift = item.horizontalAlignment === Text.AlignRight ? item.width - item.contentWidth
                                : item.horizontalAlignment === Text.AlignHCenter ? (item.width - item.contentWidth) / 2 : 0;
                    const p = item.mapToItem(root, shift + lead, 0), q = item.mapToItem(root, shift + lead + w, item.contentHeight);
                    if (!best || p.y < best.y)
                        best = { x: p.x, y: p.y, w: q.x - p.x, h: q.y - p.y, size: item.font.pixelSize * (q.y - p.y) / Math.max(1, item.contentHeight), text: metrics.text };
                }
            }
            for (const child of item.children ?? [])
                walk(child);
        };
        walk(archive);
        return best;
    }
    // The room's own number in `scope` (the field: the title wedge's number, else the index ribbon's): the largest
    // text that is exactly `number`.
    function targetIn(scope, number) {
        let best = null;
        const walk = item => {
            if (!item || !item.visible || item.opacity === 0)
                return;
            if (typeof item.text === "string" && item.text === number && item.font !== undefined && (!best || item.font.pixelSize > best.font.pixelSize))
                best = item;
            for (const child of item.children ?? [])
                walk(child);
        };
        walk(scope);
        if (!best)
            return null;
        const p = best.mapToItem(root, 0, 0), q = best.mapToItem(root, best.contentWidth, best.contentHeight);
        return { x: p.x, y: p.y, w: q.x - p.x, h: q.y - p.y, size: best.font.pixelSize * (q.y - p.y) / Math.max(1, best.contentHeight), text: number };
    }
    TextMetrics { id: metrics }

    function start(a, b) {
        root.from = a;
        root.to = b;
        cut.restart();
    }
    signal finished
    NumberAnimation {
        id: cut
        target: root
        property: "u"
        from: 0
        to: 1
        duration: Motion.scaled(820)
        onFinished: root.finished()
    }

    // The ghosts of the box on its way.
    Repeater {
        model: root.visible ? Cut.trail(root.u, 3, 0.05) : []
        Rectangle {
            required property real modelData
            required property int index
            readonly property var b: Cut.box(root.from, root.to, modelData)
            x: b.x - 3
            y: b.y - 3
            width: b.w + 6
            height: b.h + 6
            color: "transparent"
            border.width: 1
            border.color: Qt.alpha(Design.accent, 0.4 - index * 0.11)
        }
    }
    Item {
        id: frame
        x: root.now?.x ?? 0
        y: root.now?.y ?? 0
        width: root.now?.w ?? 0
        height: root.now?.h ?? 0
        // Ground under the pivot, so the room appearing round it never runs through its strokes.
        Rectangle {
            anchors.fill: parent
            anchors.margins: -3
            color: Design.background
            opacity: 1 - root.k
        }
        // The archive's type, giving way to the room's.
        FText {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: root.from?.text ?? ""
            technical: true
            font.pixelSize: Math.max(Design.caption, Math.round(root.now?.size ?? Design.caption))
            color: Design.ink
            opacity: 1 - root.k
        }
        FText {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: root.to?.text ?? ""
            headline: true
            font.pixelSize: Math.max(Design.caption, Math.round(root.now?.size ?? Design.figure))
            font.weight: Font.Black
            color: Design.accent
            opacity: root.k
        }
        // Crop marks at the four corners, as an editor marks the frame a cut is matched on.
        Repeater {
            model: 4
            Item {
                required property int index
                readonly property bool atRight: index % 2 === 1
                readonly property bool atBottom: index > 1
                x: atRight ? frame.width + 4 : -4
                y: atBottom ? frame.height + 4 : -4
                Rectangle { x: parent.atRight ? -7 : 0; width: 7; height: 1; color: Design.accent }
                Rectangle { y: parent.atBottom ? -7 : 0; width: 1; height: 7; color: Design.accent }
            }
        }
    }
}
