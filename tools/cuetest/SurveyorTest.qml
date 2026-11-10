import QtQuick
import Quickshell
import qs.adapters.fixture
import qs.core.client
import qs.view.cues
import qs.view.overdrive
import qs.view.shell
import qs.view.strata
import "view/rooms/Survey.js" as Survey   // the harness runs from the bundle root (tools/cuetest.py)

// The surveyor in the real rooms (view/overdrive/Wanderer.qml, docs/OVERDRIVE.md §16): the real Shell against the
// fixture adapter, with a surveyor mounted the way the Shell's stratum mounts it, given the shown room. In every room
// it finds ground, and its body never covers a control or a piece of text while it walks; it measures a control with
// lines outside it and writes the field book (sizes and room ids, no labels); a survey error measures a doorway in
// empty space; with no room it walks the footer, found at the neglected room's place; a release and reduced motion
// leave nothing. With SURVEY_SHOTS set, frames are saved there.
Scope {
    id: root
    readonly property var pages: ["home", "media", "performance", "workspaces", "devices", "tasks", "timers", "clipboard", "notifications", "codex"]
    function check(name, ok, detail) { ok ? console.log("CUE_PASS", name) : console.log("CUE_FAIL", name, JSON.stringify(detail ?? {})); }
    function after(ms, fn) {
        const timer = Qt.createQmlObject("import QtQuick; Timer {}", root);
        timer.interval = ms;
        timer.triggered.connect(() => { timer.destroy(); fn(); });
        timer.start();
    }
    function until(test, fn, limit) {
        const t0 = Date.now();
        const poll = () => test() || Date.now() - t0 > (limit ?? 4000) ? fn() : after(10, poll);
        poll();
    }
    readonly property string shots: Quickshell.env("SURVEY_SHOTS") || ""
    function shot(name, fn) {
        if (!shots) { fn(); return; }
        stage.grabToImage(r => { r.saveToFile(shots + "/" + name + ".png"); fn(); });
    }
    // Nothing moving but the idle loops: the switch's flight has landed and the room fills the field.
    function settled() { return Motion.activeNames.every(n => n.startsWith("idle.")); }
    function overlaps(a, b) { return a.x < b.x + b.width && a.x + a.width > b.x && a.y < b.y + b.height && a.y + a.height > b.y; }
    function body(w, x, y) { return { x: x - w.bodyW / 2, y: y - w.bodyH, width: w.bodyW, height: w.bodyH }; }
    // Every standing point at each end and the middle of every segment, against every keep-out rect.
    function groundClear(w) {
        const bad = [];
        for (const s of w.segs)
            for (const x of [s.x1, (s.x1 + s.x2) / 2, s.x2]) {
                const b = body(w, x, Survey.yAt(s, x));
                for (const r of w.keep)
                    if (root.overlaps(b, r)) bad.push({ seg: s, x: x, rect: r });
            }
        return bad;
    }
    property var journey: ({ visits: { home: 30, tasks: 12 }, seconds: { home: 900, media: 600, performance: 500, workspaces: 400,
                                                                         devices: 300, tasks: 800, timers: 700, clipboard: 20, notifications: 200, codex: 900 } })

    CoreClient { id: core }
    FixtureAdapter { id: fixture }
    ShellContext { id: context; panelOpen: true; core: core }
    FloatingWindow {
        id: window
        implicitWidth: 1120; implicitHeight: 760; visible: true
        Item {
        id: stage
        anchors.fill: parent
        Shell { id: dashboard; anchors.fill: parent; host: fixture; shell: context; core: core }
        Stratum {
            id: mount
            name: "surveyor.test"
            gpu: false
            scope: dashboard
            z: 20
            x: 0
            y: window.height - 80
            width: window.width
            height: 60
            sourceComponent: Wanderer {
                room: root.withRoom ? dashboard.shownSlot.item : null
                roomId: dashboard.shownPageId
                journey: root.journey
                rooms: root.pages
            }
        }
        }
    }
    property bool withRoom: true
    readonly property var w: mount.item
    // Watches the walking body every 16 ms against the keep-out rects of whatever ground it is on.
    property var covered: []
    property int samples: 0
    Timer {
        interval: 16
        repeat: true
        running: !!root.w && root.w.space !== root.w
        onTriggered: {
            const w = root.w;
            if (w.mode === "hop") return;
            root.samples++;
            const b = root.body(w, w.fx, w.fy);
            for (const r of w.keep)
                if (root.overlaps(b, r)) { root.covered = [...root.covered.slice(-4), { at: [w.fx, w.fy], rect: r, mode: w.mode }]; break; }
        }
    }

    Component.onCompleted: {
        ViewState.fieldBook = null;
        dashboard.navigate("tasks");
        Motion.overdrive = true;
        Motion.settleDrive();
        dashboard.ignition.settle();
        until(() => !!mount.item && dashboard.loadedPage === "tasks", () => root.rooms(0, []));
    }
    // In every room: ground found, none of it under a control or text.
    function rooms(i, found) {
        if (i === pages.length) {
            const bare = found.filter(f => f.segs < 2);
            const bad = found.filter(f => f.bad > 0);
            console.log("SURVEY_ROOMS", JSON.stringify(found.map(f => [f.page, f.segs, f.controls, f.keep])));
            check("survey.rooms", bare.length === 0 && bad.length === 0, { rooms: found });
            dashboard.navigate("tasks");
            until(() => dashboard.loadedPage === "tasks" && w.room === dashboard.shownSlot.item, () => { w.rescan(); root.walk(); });
            return;
        }
        dashboard.navigate(pages[i]);
        until(() => dashboard.loadedPage === pages[i] && w.room === dashboard.shownSlot.item && root.settled(), () => after(250, () => {
            w.rescan();
            const bad = groundClear(w);
            found.push({ page: pages[i], onRoom: w.space === w.room, segs: w.segs.length, controls: w.controls.length, keep: w.keep.length, bad: bad.length, first: bad[0] ?? null });
            shot("room-" + pages[i], () => rooms(i + 1, found));
        }));
    }
    // It walks and hops on its own for a while; its body never covers a control or text.
    function walk() {
        covered = [];
        samples = 0;
        const hopped = { seen: false };
        const watcher = () => { if (w.mode === "hop") hopped.seen = true; };
        w.modeChanged.connect(watcher);
        // Start it at a ledge's end, so the first thing it does is hop or turn.
        if (w.segs.length > 1) { w.seg = 0; w.fx = w.segs[0].x2 - 1; w.fy = w.segs[0].y2; w.dir = 1; }
        after(6000, () => {
            w.modeChanged.disconnect(watcher);
            check("survey.walk", samples > 100 && covered.length === 0 && w.space === w.room, { samples: samples, covered: covered, segs: w.segs.length });
            check("survey.hop", hopped.seen || w.segs.length < 2, { segs: w.segs.length });
            root.measure();
        });
    }
    // A survey of the nearest control: lines outside it, its reading in metres, and a station in the book.
    function measure() {
        w.autonomous = false;
        w.recent = [];
        // The control nearest any ground, and the ground nearest it.
        let n = null;
        for (const c of w.controls) {
            const at = Survey.nearest(w.segs, c.rect.x + c.rect.width / 2, c.rect.y + c.rect.height + 30);
            if (at && (!n || at.d < n.d)) n = at;
        }
        w.mode = "walk";
        w.seg = n.seg; w.fx = n.x; w.fy = n.y;
        w.begin();
        const d = w.draft, r = d?.rect;
        const outside = !!d && (d.w.y < r.y || d.w.y > r.y + r.height) && (d.h.x < r.x || d.h.x > r.x + r.width);
        const expected = Survey.reading(Survey.clean(ViewState.fieldBook, 1), r?.width ?? 0, r?.height ?? 0);
        // Its figure covers no control and no text.
        const figure = d?.spot ? { x: d.spot.x, y: d.spot.y, width: 6 * (w.reading.length + 2 + (d.kind?.length ?? 0)), height: 12 } : null;
        const clearFigure = !!figure && !w.keep.some(k => root.overlaps(figure, k));
        check("survey.measure", w.mode === "survey" && !!d && !d.error && outside && clearFigure && d.kind !== "SPOT" && w.reading === expected && /^\d+\.\d\d × \d+\.\d\d M$/.test(w.reading),
              { mode: w.mode, reading: w.reading, expected: expected, kind: d?.kind, outside: outside, figure: figure });
        after(500, () => shot("measure", () => {
            const before = Survey.clean(ViewState.fieldBook, 1).total;
            w.finish();
            const b = ViewState.fieldBook;
            const last = b?.readings?.[b.readings.length - 1];
            const text = JSON.stringify(b);
            const labels = w.controls.map(c => c.item.label ?? c.item.text ?? "").filter(s => typeof s === "string" && s.length > 3);
            check("survey.book", !!b && b.total === before + 1 && last?.room === "tasks" && b.walls?.tasks?.first > 0 && w.marks.length >= 1
                  && !labels.some(s => text.includes(s)), { book: b, labels: labels.slice(0, 4) });
            root.doorway();
        }));
    }
    // A survey error: past its first stations, on the seeded schedule, it measures a doorway in empty space.
    function doorway() {
        let seed = 0, b = null;
        for (; seed < 5000; seed++) {
            b = Object.assign(Survey.fresh(seed), { total: 40, day: "2000-01-01" });
            if (Survey.isError(b, w.today())) break;
        }
        ViewState.fieldBook = b;
        w.mode = "walk";
        w.begin();
        const d = w.draft;
        const clear = !!d && d.error && !w.keep.some(r => root.overlaps(d.rect, r));
        after(500, () => shot("doorway", () => {
            w.finish();
            const book = ViewState.fieldBook;
            const mark = w.marks[w.marks.length - 1];
            check("survey.error", clear && w.reading === "1.00 × 1.00 DOORWAY" && book.errors.length === 1 && mark.error === true,
                  { seed: seed, draft: d ? { error: d.error, rect: d.rect } : null, errors: book?.errors });
            root.footer();
        }));
    }
    // No room: it walks the footer, found where the neglected room (Clips, in this journey) sits on the rule.
    function footer() {
        root.withRoom = false;
        until(() => w.room === null && w.space === w && w.mode === "walk", () => {
            const goal = Survey.stationX(root.pages, "clipboard", w.width);
            check("survey.footer", w.space === w && Math.abs(w.fy - w.height) < 0.5 && Math.abs(w.fx - goal) < 40 && w.segs.length === 1,
                  { space: w.space === w, fx: w.fx, fy: w.fy, goal: goal, height: w.height });
            root.withRoom = true;
            root.release();
        });
    }
    // A release winds it down and destroys it; reduced motion never creates it.
    function release() {
        const live = Strata.live.includes("panel:surveyor.test");
        Motion.overdrive = false;
        until(() => !mount.item, () => {
            const gone = !mount.item && !Strata.live.includes("panel:surveyor.test") && !Motion.activeNames.includes("idle.surveyor");
            Motion.reduced = true;
            Motion.overdrive = true;
            Motion.settleDrive();
            after(300, () => {
                const none = !mount.item;
                check("survey.release", live && gone && none, { live: live, gone: gone, reduced: none, names: Motion.activeNames });
                Motion.overdrive = false;
                Motion.reduced = false;
                Motion.settleDrive();
                console.log("CUE_ACTIVE", Motion.active, JSON.stringify(Motion.activeNames));
                console.log("CUE_DONE");
                Qt.exit(0);
            });
        }, 6000);
    }
}
