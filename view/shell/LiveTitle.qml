import qs.view.ui
import qs.view.cues
import qs.view.strata
import QtQuick
import "../ui/TitleType.js" as TT

// The room's title under load (docs/OVERDRIVE.md §35; atlas #41–44), Overdrive only: the Stratum `title.type` in
// RoomSheet, laid exactly over CutTitle's name, which it takes over (the name fades as this comes in, with the
// engine). Set glyph by glyph so its anatomy can carry the room:
// - each glyph's weight and compression is the load of the content beside it (#41), the bearing glyph marked on the
//   wedge's inner edge;
// - its tracking is the room's pressure, read when the room is entered (#42);
// - past the pressure threshold it turns, glyph by glyph out from the bearing, into an instrument: mono cells on a
//   tick scale with the reading appended, and the session's crossings notched after it (#44);
// - its counters are windows onto what the room holds out of view (#43, TitleCounters, GPU only).
// Reads the room's tree (text ink and controls: rects and sizes only, never their text) every 1.5 s.
Item {
    id: root
    required property CutTitle title
    // The room's viewport (a Flickable): its content is what presses on the title.
    property Item viewport: null
    property string roomId: ""
    // False only in tests, which call rescan() themselves.
    property bool autonomous: true

    readonly property string label: title.label
    readonly property var chars: label.split("")
    readonly property real size: title.nameSize
    readonly property real k: size / 100
    // What the last scan found.
    property var loads: chars.map(() => 0)
    property real pressureNow: 0
    property real pressureEntry: 0
    property bool entered: false
    property real inkShare: 0
    property real hiddenBelow: 0
    property real hiddenAbove: 0
    readonly property int bearing: TT.bearing(loads)
    // The phase: wanted, and as each glyph shows it (the front runs glyph by glyph).
    property bool instrument: false
    property var shown: chars.map(() => false)
    readonly property bool settled: shown.every(s => s === instrument)
    property int crossings: 0
    readonly property string reading: "·" + String(Math.round(pressureNow * 100)).padStart(2, "0")
    readonly property real track: TT.tracking(pressureEntry, size)

    function advance(i) {
        const ch = chars[i];
        if (shown[i])
            return monoMetrics.advanceWidth(ch) * k * cellScale;
        const fm = [light, regular, medium, bold][[300, 400, 500, 700].indexOf(TT.weightFor(loads[i] ?? 0))] ?? bold;
        return fm.advanceWidth(ch) * k * TT.squash(loads[i] ?? 0).along;
    }
    readonly property var advances: chars.map((c, i) => { void loads; void shown; void k; return advance(i); })
    // In the instrument the reading stands at the foot of the name, where the wedge is widest; the glyphs move up.
    readonly property real readingWidth: instrument ? monoMetrics.advanceWidth(reading) * k * 0.5 + size * 0.12 : 0
    readonly property var places: TT.places(advances, track).map(x => x + readingWidth)
    readonly property real lineLength: TT.length(advances, track) + readingWidth
    readonly property real fit: lineLength > 0 ? Math.min(1, title.nameLength / lineLength) : 1
    readonly property real lineHeight: size * 0.94
    // The instrument is set smaller than the name, so more of it fits the narrowing wedge.
    readonly property real cellScale: 0.7
    readonly property real cellHeight: lineHeight * cellScale

    // Its loader puts it in CutTitle's frame.
    clip: true
    opacity: Motion.drive
    Binding { target: root.title; property: "nameOpacity"; value: 1 - root.opacity }
    Component.onDestruction: if (title) title.nameOpacity = 1

    FontMetrics { id: light; font.family: Design.sans; font.pixelSize: 100; font.weight: 300 } // scale: measured at 100
    FontMetrics { id: regular; font.family: Design.sans; font.pixelSize: 100; font.weight: 400 } // scale: measured at 100
    FontMetrics { id: medium; font.family: Design.sans; font.pixelSize: 100; font.weight: 500 } // scale: measured at 100
    FontMetrics { id: bold; font.family: Design.sans; font.pixelSize: 100; font.weight: 700 } // scale: measured at 100
    FontMetrics { id: monoMetrics; font.family: Design.mono; font.pixelSize: 100; font.weight: 500 } // scale: measured at 100

    // The room's ink, in this item's frame, clipped to what the viewport shows.
    function collect(item, box, into, depth) {
        if (depth > 40 || into.length > 4000)
            return;
        for (const it of item.children) {
            if (!it.visible || it.opacity < 0.05 || it.width <= 0 || it.height <= 0)
                continue;
            let r = null;
            if (it.activeFocusOnTab && it.enabled)
                r = it.mapToItem(root, 0, 0, it.width, it.height);
            else if (it instanceof Text && it.text !== "")
                r = it.mapToItem(root, 0, 0, Math.min(it.width, it.contentWidth), Math.min(it.height, it.contentHeight));
            if (r) {
                const x0 = Math.max(box.x, r.x), y0 = Math.max(box.y, r.y);
                const x1 = Math.min(box.x + box.width, r.x + r.width), y1 = Math.min(box.y + box.height, r.y + r.height);
                if (x1 > x0 && y1 > y0)
                    into.push({ x: x0, y: y0, width: x1 - x0, height: y1 - y0 });
                if (it instanceof Text)
                    continue;
            }
            collect(it, box, into, depth + 1);
        }
    }
    // Each glyph's band of the sheet's height, in this item's frame.
    function bands() {
        return chars.map((c, i) => {
            const a = line.mapToItem(root, places[i], lineHeight / 2), b = line.mapToItem(root, places[i] + advances[i], lineHeight / 2);
            return [a.y, b.y];
        });
    }
    function rescan() {
        const vp = viewport;
        if (!vp || !vp.contentItem)
            return;
        const box = vp.mapToItem(root, 0, 0, vp.width, vp.height);
        const rects = [];
        collect(vp.contentItem, box, rects, 0);
        const area = rects.reduce((s, r) => s + r.width * r.height, 0);
        inkShare = box.width * box.height > 0 ? Math.min(1, area / (box.width * box.height)) : 0;
        hiddenBelow = Math.max(0, vp.contentHeight - vp.contentY - vp.height);
        hiddenAbove = Math.max(0, vp.contentY);
        pressureNow = TT.pressure(vp.contentHeight, vp.height, inkShare);
        loads = TT.loads(rects, bands(), box.width);
        if (!entered) {
            pressureEntry = pressureNow;
            entered = true;
        }
        const next = TT.phase(instrument, pressureNow);
        if (next && !instrument)
            crossings = TT.cross(roomId);
        instrument = next;
    }
    function enter() {
        const cs = label.split("");
        entered = false;
        instrument = false;
        shown = cs.map(() => false);
        crossings = TT.crossings(roomId);
        loads = cs.map(() => 0);
        settle.restart();
    }
    function show(i, on) {
        const next = shown.slice();
        next[i] = on;
        shown = next;
    }
    onRoomIdChanged: enter()
    onLabelChanged: enter()
    Component.onCompleted: enter()
    Timer { id: settle; interval: 450; onTriggered: if (root.autonomous) root.rescan() }
    Timer { interval: 1500; repeat: true; running: root.autonomous && root.entered; onTriggered: root.rescan() }

    // The name, set glyph by glyph along CutTitle's edge.
    Item {
        id: line
        x: root.title.nameX
        y: root.title.nameY
        width: root.lineLength
        height: root.lineHeight
        transformOrigin: Item.TopLeft
        rotation: root.title.nameRotation
        scale: root.fit

        Item {
            id: glyphRun
            width: parent.width
            height: parent.height
            Repeater {
                model: root.chars.length
                Item {
                    id: glyph
                    required property int index
                    readonly property real load: root.loads[index] ?? 0
                    readonly property var squash: TT.squash(load)
                    readonly property bool want: root.instrument
                    // The phase this glyph has been told, after its place in the front; the flip folds it shut and
                    // open again (a split-flap), and it changes face at the fold.
                    property bool turned: false
                    readonly property bool inst: flip.value >= 0.5
                    readonly property real fold: Math.abs(2 * flip.value - 1)
                    x: root.places[index] ?? 0
                    width: root.advances[index] ?? 0
                    height: root.lineHeight
                    Tween on x { scope: root; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                    onWantChanged: if (want !== turned) front.restart()
                    onInstChanged: root.show(index, inst)
                    Timer {
                        id: front
                        interval: TT.delay(glyph.index, root.bearing)
                        onTriggered: glyph.turned = glyph.want
                    }
                    Cue { id: flip; name: "title.flip"; scope: root; on: glyph.turned; enter: 200; easing: Easing.InOutQuad }
                    Item {
                        anchors.fill: parent
                        transform: Scale { origin.y: glyph.height / 2; yScale: glyph.fold }
                        Text {
                            visible: !glyph.inst
                            text: root.chars[glyph.index] ?? ""
                            color: root.title.textColor
                            font.family: Design.sans
                            font.pixelSize: root.size // scale: the name fitted to the wedge
                            font.weight: TT.weightFor(glyph.load)
                            lineHeight: 0.8
                            renderType: Text.QtRendering
                            transform: Scale { xScale: glyph.squash.along; yScale: glyph.squash.across }
                        }
                        Rectangle {
                            visible: glyph.inst
                            x: 1
                            y: root.cellHeight * 0.06
                            width: glyph.width - 2
                            height: root.cellHeight * 0.78
                            color: "transparent"
                            border.width: 1
                            border.color: Qt.alpha(root.title.textColor, 0.45)
                        }
                        Text {
                            visible: glyph.inst
                            width: glyph.width
                            horizontalAlignment: Text.AlignHCenter
                            text: root.chars[glyph.index] ?? ""
                            color: root.title.textColor
                            font.family: Design.mono
                            font.pixelSize: root.size * root.cellScale // scale: the instrument's cells
                            font.weight: 500
                            lineHeight: 0.8
                            renderType: Text.QtRendering
                        }
                        // The instrument's scale: a long tick at each cell, a short one at its middle.
                        Rectangle {
                            visible: glyph.inst
                            y: root.cellHeight * 0.86
                            width: 1
                            height: root.cellHeight * 0.1
                            color: root.title.textColor
                        }
                        Rectangle {
                            visible: glyph.inst
                            x: glyph.width / 2
                            y: root.cellHeight * 0.86
                            width: 1
                            height: root.cellHeight * 0.05
                            color: Qt.alpha(root.title.textColor, 0.6)
                        }
                    }
                }
            }
        }
        // The reading, at the foot once the instrument is called for; the session's crossings notched over it.
        Item {
            visible: root.instrument
            width: root.readingWidth
            height: root.lineHeight
            Text {
                y: root.cellHeight * 0.2
                text: root.reading
                color: Design.accent
                font.family: Design.mono
                font.pixelSize: root.size * 0.5 // scale: the reading at half the name
                font.weight: 500
                lineHeight: 0.8
            }
            Row {
                y: root.lineHeight * 0.12
                spacing: Math.max(2, root.size * 0.03)
                Repeater {
                    model: Math.min(9, root.crossings)
                    Rectangle { width: Math.max(1, root.size * 0.02); height: root.lineHeight * 0.14; color: Design.accent }
                }
            }
        }
        // Counter windows: a GPU stratum of its own, in the line's frame so the windows lean with the glyphs.
        Stratum {
            name: "title.counters"
            scope: root
            wanted: root.hiddenBelow > 0 || root.hiddenAbove > 0
            width: line.width
            height: line.height
            sourceComponent: TitleCounters {
                glyphs: glyphRun
                frame: root
                viewport: root.viewport
                settled: root.settled
                shift: root.hiddenBelow > 0 ? Math.min(root.viewport?.height ?? 0, root.hiddenBelow) : -Math.min(root.viewport?.height ?? 0, root.hiddenAbove)
            }
        }
    }
    // The bearing: where the room rests on the title, a notch on the wedge's inner edge.
    Rectangle {
        id: bearingMark
        readonly property var band: root.bearing >= 0 ? root.bands()[root.bearing] : [0, 0]
        visible: root.bearing >= 0
        x: root.title.leftSide ? root.width - width : 0
        y: Math.min(band[0], band[1]) + Math.abs(band[1] - band[0]) / 2 - height / 2
        width: 4
        height: Math.max(8, Math.abs(band[1] - band[0]))
        color: Design.accent
        Tween on y { scope: root; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
    }
}
