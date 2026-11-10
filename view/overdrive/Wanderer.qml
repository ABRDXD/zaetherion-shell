import qs.view.cues
import qs.view.shell
import qs.view.ui
import QtQuick
import QtQuick.Shapes
import "../rooms/SurveyorNotes.js" as Notes
import "../rooms/Survey.js" as Survey

// The surveyor (docs/OVERDRIVE.md §16). In Overdrive, Mote, the badly supervised surveying instrument (FCreature),
// walks the top edges of the shown room's planes and rules, hops from one to the next, and stops to measure the
// controls it passes: dimension lines drawn outside each control as on a drawing, with 78° ticks and its reading in
// metres. Where it measured it plants a station mark that fades. It never stands over a control or text (Survey.js
// keeps its body out of their rects) and takes no input but its own poke. What it measures goes into the field book
// (ViewState.fieldBook), read back in the field archive; on a seeded schedule a station measures a doorway that is
// not there and records a coordinate with no room (atlas #55), and once in a while it corrects its own scale (#56).
// With no room to walk (the orbit open, or a mount that passes none) it walks this item's bottom edge, the footer
// rule, and is found nearer the room you have neglected (#57). Its pace follows the engine, so a release winds it
// down to a stop as the stratum goes.
Item {
    id: root
    // The shown room, the visible window onto it (its Flickable, found when not given) and its id.
    property Item room: null
    property Item viewport: null
    property string roomId: ""
    // The journey (core/journey.py) and the footer's rooms in order, for where it is found on the rule.
    property var journey: null
    property var rooms: []

    readonly property real creatureScale: 0.32
    // Its body as Survey.js keeps it clear: the drawn instrument (about 37 × 20 px, 23 with its step).
    readonly property real bodyW: 40
    readonly property real bodyH: 24
    readonly property Item window: viewport ?? flickableAbove(room)
    // It decides for itself (false only in tests, which drive it step by step).
    property bool autonomous: true
    // Where it walks: the room while it can be seen, otherwise this item (the footer).
    property Item space: root
    property var segs: []
    property var keep: []
    property var controls: []
    property var bounds: ({ x: 0, y: 0, width: 0, height: 0 })
    property int seg: -1
    // The edge it falls back on (the bottom of the window): it climbs off it onto real ledges when it can.
    property int floorEdge: -1
    readonly property bool onFloor: seg >= 0 && seg < segs.length && segs[seg].edge === floorEdge
    property real fx: width * 0.18
    property real fy: height
    property int dir: 1
    property string mode: "walk"   // walk | hop | survey
    property real stride: 0
    property real hurry: 1
    property double clock: 0
    property var leap: null        // a hop: {x0, y0, x1, y1, seg, t, span}
    property var draft: null       // what it is measuring, in space coordinates
    property double surveyed: 0    // when the survey started (clock)
    property var recent: []        // [{item, at}] measured lately, not measured again for a while
    property var marks: []         // [{x, y, born, space, station, error}]
    property string reading: ""
    property real sightAngle: -78
    property string note: ""
    property int pokes: 0
    readonly property real tilt: mode === "hop" && leap ? -root.dir * 12 * Math.sin(Math.PI * leap.t)
        : seg >= 0 && seg < segs.length ? Math.atan2(segs[seg].y2 - segs[seg].y1, Math.max(1, segs[seg].x2 - segs[seg].x1)) * 180 / Math.PI : 0

    FrameAnimation {
        id: frames
        running: Motion.engaged && root.visible
        onTriggered: root.step(frameTime)
    }
    // Reported as an idle loop: it runs, by design, for as long as Overdrive does.
    Activity { name: "idle.surveyor"; running: frames.running }
    Timer {
        id: decisions
        running: frames.running && root.autonomous
        repeat: true
        interval: 2600
        onTriggered: root.decide()
    }
    // The ground is read again every so often (a list grows, a plane slides in), never per frame.
    Timer {
        id: rescanning
        running: frames.running
        repeat: true
        interval: 1500
        triggeredOnStart: true
        onTriggered: root.rescan()
    }
    Timer {
        id: hush
        interval: 3600
        onTriggered: root.note = ""
    }
    onRoomChanged: rescan()

    // The scrolling window a room sits in: the nearest Flickable above it.
    function flickableAbove(item) {
        for (let at = item?.parent ?? null, n = 0; at && n < 5; at = at.parent, n++)
            if (at.contentItem && at.contentY !== undefined && typeof at.flick === "function")
                return at;
        return null;
    }
    // How visible an item is through its parents (opacity × visibility), up to this item's parent.
    function presence(item) {
        let p = 1;
        for (let at = item; at && at !== root.parent; at = at.parent) {
            if (!at.visible)
                return 0;
            p *= at.opacity;
        }
        return p;
    }
    // One walk of the room's tree: the planes' and rules' top edges, and every control and piece of text as a
    // rect the surveyor must keep out of; the controls are also what it measures.
    function collect(item, into, edges, keep, controls) {
        for (const it of item.children) {
            if (!it.visible || it.opacity < 0.05 || it.width <= 0 || it.height <= 0)
                continue;
            if (it.activeFocusOnTab && it.enabled) {
                const r = it.mapToItem(into, 0, 0, it.width, it.height);
                keep.push(r);
                controls.push({ item: it, rect: r });
                // Standing on a control's top edge covers none of it, so its top is ground too.
                if (it.width >= 60) {
                    const a = it.mapToItem(into, 0, 0), b = it.mapToItem(into, it.width, 0);
                    edges.push({ x1: a.x, y1: a.y, x2: b.x, y2: b.y });
                }
                continue;
            }
            if (it instanceof Text) {
                if (it.text !== "") {
                    // Only the ink: a wide, right-aligned caption keeps out of its words, not its whole row.
                    const cw = Math.max(1, Math.min(it.width, it.contentWidth)), ch = Math.max(1, Math.min(it.height, it.contentHeight));
                    const ox = it.horizontalAlignment === Text.AlignRight ? it.width - cw : it.horizontalAlignment === Text.AlignHCenter ? (it.width - cw) / 2 : 0;
                    const oy = it.verticalAlignment === Text.AlignBottom ? it.height - ch : it.verticalAlignment === Text.AlignVCenter ? (it.height - ch) / 2 : 0;
                    keep.push(it.mapToItem(into, ox, oy, cw, ch));
                }
                continue;
            }
            // Ground: the top edge of a plane, a rule or a filled card, and the line of a hairline.
            const edge = (x1, y1, x2, y2) => {
                const a = it.mapToItem(into, x1, y1), b = it.mapToItem(into, x2, y2);
                edges.push({ x1: a.x, y1: a.y, x2: b.x, y2: b.y });
            };
            if (it instanceof Plane) {
                if (it.fillColor.a > 0 && it.width >= 60)
                    edge((it.slant & 1 ? it.run : 0) + it.cut, 0, it.width - it.cut, 0);
                continue;
            }
            if (it instanceof FRule) {
                if (it.width >= 60)
                    edge(0, 4, Math.max(0, it.width - 42), 4);
                continue;
            }
            if (it instanceof Hairline) {
                if (it.width >= 60)
                    edge(0, Math.round(it.height / 2), it.width, Math.round(it.height / 2));
                continue;
            }
            if (it instanceof Rectangle && it.width >= 80 && (it.color.a > 0.25 || it.border.width > 0))
                edge(0, 0, it.width, 0);
            collect(it, into, edges, keep, controls);
        }
    }
    function rescan() {
        if (!frames.running)
            return;
        const roomShown = !!room && presence(room) > 0.5 && (!window || presence(window) > 0.5);
        const next = roomShown ? room : root;
        const edges = [], keepOut = [], found = [];
        let box;
        if (next === root) {
            floorEdge = -1;
            box = { x: 0, y: -bodyH - 4, width: width, height: height + bodyH + 4 };
            edges.push({ x1: 0, y1: height, x2: width, y2: height });
        } else {
            box = window ? window.mapToItem(room, 0, 0, window.width, window.height) : { x: 0, y: 0, width: room.width, height: room.height };
            collect(room, room, edges, keepOut, found);
            // The bottom of the window is always ground, so it is never stranded.
            floorEdge = edges.length;
            edges.push({ x1: box.x, y1: box.y + box.height - 1, x2: box.x + box.width, y2: box.y + box.height - 1 });
        }
        const changed = next !== space;
        if (changed) {
            // Carry it over: where it stood, seen from the new ground.
            const p = space ? space.mapToItem(next, fx, fy) : Qt.point(fx, fy);
            fx = p.x;
            fy = p.y;
            space = next;
            leap = null;
            draft = null;
            if (mode !== "walk")
                mode = "walk";
        }
        bounds = box;
        keep = keepOut;
        controls = found;
        segs = Survey.ledges(edges, keepOut, bodyW, bodyH, box, 24);
        if (mode === "hop")
            return;
        if (changed && space === root) {
            // Found on the footer nearer the room you have neglected.
            const goal = parallaxX();
            if (goal >= 0)
                fx = goal;
        }
        seat(changed);
    }
    // Back onto the ground after a rescan: snapped when it is still where it stood, otherwise a hop to the nearest
    // standing point (or set down there, if that is too far to jump).
    function seat(arriving) {
        // Arriving in a room, it makes for a real ledge rather than the floor.
        const ledge = arriving ? Survey.nearest(segs, fx, fy, floorEdge) : null;
        const n = ledge && ledge.d < 420 ? ledge : Survey.nearest(segs, fx, fy);
        if (!n) {
            seg = -1;
            return;
        }
        if (n.d < 4 || mode === "survey" && n.d < 12) {
            seg = n.seg;
            fx = n.x;
            fy = n.y;
        } else if (n.d < 420 && Motion.drive > 0.2) {
            jump(n);
        } else {
            seg = n.seg;
            fx = n.x;
            fy = n.y;
            mode = "walk";
        }
    }
    function jump(to) {
        leap = { x0: fx, y0: fy, x1: to.x, y1: to.y, seg: to.seg, t: 0, span: Survey.hopTime(fx, fy, to.x, to.y) };
        dir = to.x >= fx ? 1 : -1;
        draft = null;
        mode = "hop";
    }
    readonly property var reach: ({ across: 220, up: 150, down: 240 })
    function parallaxX() {
        if (space !== root)
            return -1;
        const id = Survey.neglected(journey, rooms);
        return id === "" ? -1 : Survey.stationX(rooms, id, width);
    }
    function step(dt) {
        clock += dt;
        hurry = Math.max(1, hurry - dt * 1.5);
        if (mode === "hop" && leap) {
            const t = Math.min(1, leap.t + dt * Motion.drive / Math.max(0.05, leap.span));
            const p = Survey.arc(leap.x0, leap.y0, leap.x1, leap.y1, t);
            fx = p.x;
            fy = p.y;
            leap = Object.assign({}, leap, { t: t });
            if (t >= 1) {
                seg = leap.seg < segs.length ? leap.seg : -1;
                leap = null;
                mode = "walk";
                seat();
            }
        } else if (mode === "walk" && seg >= 0 && seg < segs.length) {
            const s = segs[seg], speed = 30 * hurry * Motion.drive;
            fx += dir * speed * dt;
            stride += speed * dt;
            if (fx >= s.x2 || fx <= s.x1) {
                fx = Math.max(s.x1, Math.min(s.x2, fx));
                edge();
            }
            if (mode === "walk")
                fy = Survey.yAt(s, fx);
        }
        if (marks.length > 0 && clock - marks[0].born > 45)
            marks = marks.slice(1);
        place();
    }
    // At a segment's end: hop on to another ledge within reach, or turn back.
    function edge() {
        const options = Survey.hops(segs, seg, fx, fy, dir, root.reach);
        // Real ledges before the floor.
        options.sort((a, b) => (segs[a.seg].edge === floorEdge) - (segs[b.seg].edge === floorEdge));
        if (options.length > 0 && Math.random() < 0.7)
            jump(options[Math.random() < 0.75 ? 0 : Math.floor(Math.random() * options.length)]);
        else
            dir = -dir;
    }
    // The room's coordinates drawn in this item's: one affine map per frame (it moves with scrolling and flights).
    function place() {
        if (space === root) {
            placement.matrix = Qt.matrix4x4();
            return;
        }
        const o = space.mapToItem(root, 0, 0), ux = space.mapToItem(root, 1, 0), uy = space.mapToItem(root, 0, 1);
        placement.matrix = Qt.matrix4x4(ux.x - o.x, uy.x - o.x, 0, o.x, ux.y - o.y, uy.y - o.y, 0, o.y, 0, 0, 1, 0, 0, 0, 0, 1);
    }
    function today() {
        const d = new Date();
        return d.getFullYear() + "-" + String(d.getMonth() + 1).padStart(2, "0") + "-" + String(d.getDate()).padStart(2, "0");
    }
    function book() {
        return Survey.clean(ViewState.fieldBook, ViewState.fieldBook?.seed ?? Math.floor(Math.random() * 4294967296));
    }
    function decide() {
        decisions.interval = 1800 + Math.round(Math.random() * 2600);
        if (mode === "survey") {
            finish();
            return;
        }
        if (mode !== "walk" || seg < 0)
            return;
        // On the floor, it climbs onto a ledge within reach when there is one.
        if (onFloor && Math.random() < 0.6) {
            const up = Survey.hops(segs, seg, fx, fy, dir, root.reach).filter(o => segs[o.seg].edge !== floorEdge);
            if (up.length > 0) {
                jump(up[0]);
                return;
            }
        }
        // On the footer, it makes its way to the neglected room's place on the rule and surveys there.
        const goal = parallaxX();
        if (goal >= 0 && Math.abs(goal - fx) > 30 && Math.random() < 0.8) {
            dir = goal > fx ? 1 : -1;
            return;
        }
        if (Math.random() < 0.5)
            begin();
    }
    // Starts a survey: of the nearest control it has not measured lately; a doorway that is not there when the
    // schedule says so; or, with nothing near, a sighting off into the room.
    function begin() {
        const b = book(), day = today();
        const eye = Qt.point(fx + dir * 8, fy - bodyH * 0.6);
        recent = recent.filter(r => clock - r.at < 90 && r.item);
        const skip = [];
        controls.forEach((c, i) => { if (recent.some(r => r.item === c.item)) skip.push(i); });
        if (space !== root && Survey.isError(b, day)) {
            const door = Survey.freeRect(keep, bounds, 46, 72, eye.x, eye.y - 60);
            if (door) {
                draft = Object.assign(Survey.dimension(door, eye, bounds), { rect: door, kind: "", error: true, item: null,
                                      sight: { x1: eye.x, y1: eye.y, x2: door.x + door.width / 2, y2: door.y + door.height } });
                reading = "1.00 × 1.00 DOORWAY";
                placeFigure(eye);
                startSurvey(door);
                return;
            }
        }
        const i = Survey.closest(controls.map(c => c.rect), eye.x, eye.y, 320, skip);
        if (i >= 0) {
            const c = controls[i], r = c.rect;
            const corner = Qt.point(Math.max(r.x, Math.min(r.x + r.width, eye.x)), Math.max(r.y, Math.min(r.y + r.height, eye.y)));
            draft = Object.assign(Survey.dimension(r, eye, bounds), { rect: r, kind: Survey.kindOf(c.item), error: false, item: c.item,
                                  sight: { x1: eye.x, y1: eye.y, x2: corner.x, y2: corner.y } });
            reading = Survey.reading(b, r.width, r.height);
            placeFigure(eye);
            recent = [...recent, { item: c.item, at: clock }];
            startSurvey(r);
            return;
        }
        draft = null;
        sightAngle = -(62 + Math.random() * 30);
        reading = "Δ " + (0.8 + Math.random() * 7.2).toFixed(2) + " · " + String(Math.round(Math.random() * 359)).padStart(3, "0") + "°";
        mode = "survey";
        surveyed = clock;
    }
    // The figure goes where it covers nothing (Survey.labelSpot), measured in its own type.
    function placeFigure(eye) {
        figure.text = reading + (draft.kind ? "  " + draft.kind : "");
        draft = Object.assign({}, draft, { spot: Survey.labelSpot(draft, keep, figure.implicitWidth, figure.implicitHeight, bounds, eye) });
    }
    FText {
        id: figure
        visible: false
        technical: true
        font.pixelSize: 9   // scale: a dimension's figure, set under a caption
    }
    function startSurvey(r) {
        dir = r.x + r.width / 2 >= fx ? 1 : -1;
        mode = "survey";
        surveyed = clock;
    }
    // Ends a survey: the station is planted and written in the field book.
    function finish() {
        const day = today();
        let b = Survey.calibrate(book(), day);
        const d = draft;
        const error = !!d && d.error;
        if (error)
            b = Survey.error(b, day);
        b = Survey.enter(b, d && !error && space !== root ? { room: roomId, kind: d.kind, w: d.rect.width, h: d.rect.height, wall: bounds.width }
                                                           : { room: space !== root ? roomId : "", kind: "", w: 0, h: 0, wall: space !== root ? bounds.width : 0 }, day);
        ViewState.writeFieldBook(b);
        marks = [...marks.slice(-13), { x: fx, y: fy, born: clock, space: space, station: b.total, error: error }];
        draft = null;
        mode = "walk";
        if (Math.random() < 0.35)
            dir = -dir;
    }
    function poke() {
        mote.press();
        const lost = mode === "survey";
        note = lost ? Notes.STRAY[0] : Notes.STRAY[1 + pokes++ % (Notes.STRAY.length - 1)];
        hush.restart();
        if (mode === "survey") {
            draft = null;
            mode = "walk";
        }
        dir = -dir;
        hurry = 3.2;
    }

    Item {
        id: overlay
        transform: Matrix4x4 { id: placement }
        opacity: Motion.drive

        // The stations it has planted: a triangulation mark and its number, fading over 45 s. An error's is red.
        Repeater {
            model: root.marks
            Item {
                id: mark
                required property var modelData
                visible: modelData.space === root.space
                x: modelData.x
                y: modelData.y
                opacity: Math.max(0, 1 - (root.clock - modelData.born) / 45)
                Shape {
                    x: -4
                    y: -8
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        strokeColor: mark.modelData.error ? Design.danger : Design.accent
                        strokeWidth: 1
                        fillColor: "transparent"
                        startX: 4; startY: 0
                        PathLine { x: 8; y: 7 }
                        PathLine { x: 0; y: 7 }
                        PathLine { x: 4; y: 0 }
                    }
                }
                Rectangle { x: -0.5; y: -4.5; width: 2; height: 2; color: mark.modelData.error ? Design.danger : Design.accent }
                FText {
                    x: 7
                    y: -11
                    text: "S " + mark.modelData.station + (mark.modelData.error ? " ?" : "")
                    technical: true
                    font.pixelSize: 9   // scale: a station number, smaller than a caption, off the ground
                    color: mark.modelData.error ? Design.danger : Design.faint
                }
            }
        }

        // The drafting of what it measures: extension and dimension lines outside the object, 78° ticks at their
        // ends, drawn out over a third of a second; the reading beside the width line.
        Item {
            id: drafting
            readonly property var d: root.draft
            readonly property real drawn: Math.min(1, (root.clock - root.surveyed) / 0.35)
            visible: root.mode === "survey" && !!d
            readonly property color ink: d && d.error ? Design.danger : Design.accent
            // The doorway that is not there: a dashed outline in empty space.
            Shape {
                visible: !!drafting.d && drafting.d.error
                x: drafting.d ? drafting.d.rect.x : 0
                y: drafting.d ? drafting.d.rect.y : 0
                opacity: drafting.drawn * 0.8
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeColor: Design.danger
                    strokeWidth: 1
                    strokeStyle: ShapePath.DashLine
                    dashPattern: [3, 3]
                    fillColor: "transparent"
                    startX: 0; startY: 72
                    PathLine { x: 0; y: 0 }
                    PathLine { x: 46; y: 0 }
                    PathLine { x: 46; y: 72 }
                }
            }
            // The sight line from its eye to the corner it reads.
            Shape {
                visible: !!drafting.d
                preferredRendererType: Shape.CurveRenderer
                opacity: 0.7
                ShapePath {
                    strokeColor: drafting.ink
                    strokeWidth: 1
                    strokeStyle: ShapePath.DashLine
                    dashPattern: [1, 3]
                    fillColor: "transparent"
                    startX: drafting.d ? drafting.d.sight.x1 : 0
                    startY: drafting.d ? drafting.d.sight.y1 : 0
                    PathLine {
                        x: drafting.d ? drafting.d.sight.x1 + (drafting.d.sight.x2 - drafting.d.sight.x1) * drafting.drawn : 0
                        y: drafting.d ? drafting.d.sight.y1 + (drafting.d.sight.y2 - drafting.d.sight.y1) * drafting.drawn : 0
                    }
                }
            }
            // Width: two extension lines, the dimension line between them, a tick at each end.
            Repeater {
                model: drafting.d ? drafting.d.w.ext : []
                Rectangle {
                    required property var modelData
                    x: modelData.x - 0.5
                    y: Math.min(modelData.y1, modelData.y2)
                    width: 1
                    height: Math.abs(modelData.y2 - modelData.y1) * drafting.drawn
                    color: drafting.ink
                    opacity: 0.6
                }
            }
            Rectangle {
                visible: !!drafting.d
                x: drafting.d ? drafting.d.w.x1 : 0
                y: drafting.d ? drafting.d.w.y - 0.5 : 0
                width: drafting.d ? (drafting.d.w.x2 - drafting.d.w.x1) * drafting.drawn : 0
                height: 1
                color: drafting.ink
            }
            Repeater {
                model: drafting.d ? [drafting.d.w.x1, drafting.d.w.x2] : []
                Rectangle {
                    required property var modelData
                    x: modelData - 0.5
                    y: drafting.d.w.y - 4
                    width: 1
                    height: 8
                    rotation: 12
                    color: drafting.ink
                    opacity: drafting.drawn
                }
            }
            // Height: the same on the side facing it.
            Repeater {
                model: drafting.d ? drafting.d.h.ext : []
                Rectangle {
                    required property var modelData
                    x: Math.min(modelData.x1, modelData.x2)
                    y: modelData.y - 0.5
                    width: Math.abs(modelData.x2 - modelData.x1) * drafting.drawn
                    height: 1
                    color: drafting.ink
                    opacity: 0.6
                }
            }
            Rectangle {
                visible: !!drafting.d
                x: drafting.d ? drafting.d.h.x - 0.5 : 0
                y: drafting.d ? drafting.d.h.y1 : 0
                width: 1
                height: drafting.d ? (drafting.d.h.y2 - drafting.d.h.y1) * drafting.drawn : 0
                color: drafting.ink
            }
            Repeater {
                model: drafting.d ? [drafting.d.h.y1, drafting.d.h.y2] : []
                Rectangle {
                    required property var modelData
                    x: drafting.d.h.x - 4
                    y: modelData - 0.5
                    width: 8
                    height: 1
                    rotation: -78
                    color: drafting.ink
                    opacity: drafting.drawn
                }
            }
            FText {
                visible: !!drafting.d
                x: drafting.d?.spot?.x ?? 0
                y: drafting.d?.spot?.y ?? 0
                text: root.reading + (drafting.d && drafting.d.kind ? "  " + drafting.d.kind : "")
                technical: true
                font.pixelSize: 9   // scale: a dimension's figure, set under a caption
                color: drafting.ink
                opacity: drafting.drawn
            }
        }

        // A sighting with nothing to measure: a dashed line up into the room at the angle it reads.
        Item {
            visible: root.mode === "survey" && !root.draft
            x: root.fx
            y: root.fy - root.bodyH * 0.6
            Repeater {
                model: 14
                Rectangle {
                    required property int index
                    readonly property real d: 10 + index * 9
                    x: Math.cos(root.sightAngle * Math.PI / 180) * d * root.dir
                    y: Math.sin(root.sightAngle * Math.PI / 180) * d
                    width: 3
                    height: 1
                    rotation: root.sightAngle
                    color: Design.accent
                    opacity: 0.85 - index * 0.05
                }
            }
            FText {
                x: root.dir > 0 ? 18 : -implicitWidth - 18
                y: -root.bodyH
                text: root.reading
                technical: true
                font.pixelSize: Design.caption
                color: Design.accent
            }
        }

        // The instrument itself, its feet on the ground, leaning with the slope or the hop.
        Item {
            id: body
            x: root.fx
            y: root.fy
            rotation: root.tilt
            FCreature {
                id: mote
                width: 180
                height: 120
                ground: false
                enabled: false
                x: -90
                // Its feet (y 90 of 120) on the ground; a little bob at each step while walking.
                y: -60 - 30 * root.creatureScale - (root.mode === "walk" ? Math.abs(Math.sin(root.stride / 7)) * 2.5 : 0)
                awake: root.mode === "survey" || poke.containsMouse
                transform: Scale { origin.x: 90; origin.y: 60; xScale: root.creatureScale * root.dir; yScale: root.creatureScale }
            }
            // Its own hit area, the body only: nothing under it can be a control, so it takes no one's click.
            MouseArea {
                id: poke
                x: -root.bodyW / 2
                y: -root.bodyH + 4
                width: root.bodyW
                height: root.bodyH - 4
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.poke()
            }
            // What it says when poked.
            FText {
                visible: root.note !== ""
                x: -implicitWidth / 2
                y: -root.bodyH - 16
                text: root.note
                aside: true
                font.pixelSize: Design.caption
                color: Design.muted
            }
        }
    }
}
