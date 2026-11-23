import QtQuick
import Quickshell
import qs.view.cues
import qs.view.strata
import qs.view.shell

// The room title under load (view/shell/LiveTitle.qml; docs/OVERDRIVE.md §35, atlas #41–44), on the real RoomSheet
// with a room's Flickable laid over it as the Shell lays it. Silent: CutTitle's own name, nothing else. Overdrive:
// the glyphs beside the room's ink are loaded and set heavier, the bearing among them; the tracking is read on entry
// and holds until the room is entered again; past the threshold the name turns instrument glyph by glyph, with its
// reading and a crossing, and turns back well below it; a release leaves CutTitle's name and nothing else. With
// TITLE_SHOTS set, frames are saved there.
Scope {
    id: root
    readonly property string shots: Quickshell.env("TITLE_SHOTS") || ""
    // tools/overdrive/title_frames.py runs this on the GPU, where the counter windows load too.
    readonly property bool gpu: (Quickshell.env("TITLE_GPU") || "") !== ""
    function check(name, ok, detail) { ok ? console.log("CUE_PASS", name) : console.log("CUE_FAIL", name, JSON.stringify(detail ?? {})); }
    function after(ms, fn) {
        const timer = Qt.createQmlObject("import QtQuick; Timer {}", root);
        timer.interval = ms;
        timer.triggered.connect(() => { timer.destroy(); fn(); });
        timer.start();
    }
    function shot(name, then) {
        if (root.shots === "") { then(); return; }
        stage.grabToImage(r => { r.saveToFile(root.shots + "/" + name + ".png"); then(); });
    }
    // Rows of ink: `top` px of empty room, then `n` rows.
    property int top: 420
    property int rows: 7
    property string room: "tasks"
    FloatingWindow {
        id: window
        implicitWidth: 900; implicitHeight: 700; visible: true
        color: "black"
        Item {
            id: stage
            width: 900
            height: 700
            RoomSheet {
                id: sheet
                width: 900
                height: 700
                entry: ({ id: root.room, name: Quickshell.env("TITLE_NAME") || "Tasks", about: "" })
                plan: ({ side: "left" })
                number: "05"
                cut: 150
            }
            // The counters' mask on its own (its window needs the GPU; the mask doesn't): a word with one enclosed
            // counter (O) and one open one (C), traced from the drawn type.
            Item {
                id: word
                y: 720
                width: 360
                height: 120
                Text { text: "OC"; font.pixelSize: 110; font.weight: Font.Bold; color: "black" } // scale: a fixture word, big enough to have counters
            }
            Loader { id: traced; active: false; sourceComponent: TitleCounters { width: 360; height: 120; glyphs: word; frame: stage; viewport: roomView } }
            Flickable {
                id: roomView
                x: 170
                width: 700
                height: 700
                contentHeight: content.height
                clip: true
                Column {
                    id: content
                    width: 700
                    Item { width: 1; height: root.top }
                    Repeater {
                        model: root.rows
                        Text { width: 680; height: 42; text: "MMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMM"; font.pixelSize: 34; clip: true; elide: Text.ElideRight; color: "white" } // scale: fixture rows of ink
                    }
                }
            }
        }
    }
    function find(item, test) {
        if (!item) return null;
        if (test(item)) return item;
        for (const child of item.children ?? []) { const f = find(child, test); if (f) return f; }
        return null;
    }
    function layer() { return sheet.children.find(c => c.name === "title.type") ?? null; }
    function title() { return sheet.children.find(c => c.nameOpacity !== undefined) ?? null; }
    function overdrive(on) { Motion.overdrive = on; Motion.settleDrive(); }

    Component.onCompleted: after(300, () => {
        check("title.silent", layer() && !layer().item && title().nameOpacity === 1 && sheet.roomViewport === roomView,
              { item: !!layer()?.item, opacity: title()?.nameOpacity, found: sheet.roomViewport === roomView });
        sheet.journey = { seconds: { tasks: 20000 }, visits: { tasks: 80 } };
        overdrive(true);
        after(900, () => {
            // The sheet handled: Tasks lived in for hours and opened eighty times.
            const wear = sheet.children.find(c => c.name === "sheet.wear")?.item;
            check("sheet.wear", !!wear && wear.worn > 0.8 && wear.ear === 26 && wear.visits === 80, { found: !!wear, worn: wear?.worn, ear: wear?.ear });
            // The cockled sheet: a hot processor (88 °C) cockles it and swells it; a minute at 40 °C later it is still
            // warm, the thermal mass keeping part of the hot spell.
            const cockle = sheet.children.find(c => c.name === "sheet.cockle")?.item;
            if (cockle) {
                cockle.autonomous = false;
                cockle.take({ running: true, temp: 88, sensor: "k10temp" }, 1000);
            }
            const hot = cockle ? [cockle.cockle, sheet.swell] : [];
            if (cockle)
                cockle.take({ running: true, temp: 40, sensor: "k10temp" }, 61000);
            check("sheet.cockle", !!cockle && hot[0] > 0.9 && hot[1] > 3 && cockle.cockle > 0.3 && cockle.cockle < hot[0],
                  { found: !!cockle, hot: hot, after: cockle?.cockle });
            // The sundial: GPU only. A morning sun in the east, ten degrees up: shadows fall long to the west.
            const dial = sheet.children.find(c => c.name === "sheet.sundial")?.item;
            if (dial)
                dial.sky = { bodies: { sun: { azimuth: 95, altitude: 10 }, moon: { azimuth: 0, altitude: -20 } }, moon: { illumination: 0.3 } };
            check("sheet.sundial", root.gpu ? (!!dial && dial.light?.body === "sun" && dial.cast.x < -20 && Math.abs(dial.cast.y) < 5)
                                            : !Strata.live.includes("panel:sheet.sundial"),
                  { gpu: root.gpu, found: !!dial, light: dial?.light, cast: dial?.cast });
            const t = layer()?.item;
            if (!t) { check("title.load", false, { loaded: false }); return finish(); }
            t.autonomous = false;
            t.rescan();
            // The name reads up from the foot of the wedge: its first glyphs are beside the rows (the lower half).
            const low = t.loads.slice(0, 2), high = t.loads.slice(-2);
            check("title.load", Math.min(...low) > 0.05 && Math.max(...high) < Math.min(...low) && t.bearing >= 0 && t.bearing < 3
                  && title().nameOpacity === 0 && Strata.live.includes("panel:title.counters") === root.gpu,
                  { loads: t.loads, bearing: t.bearing, name: title().nameOpacity, live: Strata.live });
            shot("loaded", () => {
                const entryTrack = t.track;
                // Many more rows: the room now overflows, but the tracking holds until it is entered again.
                root.top = 0;
                root.rows = 60;
                after(100, () => {
                    t.rescan();
                    const held = t.track === entryTrack && t.pressureNow > t.pressureEntry;
                    t.enter();
                    t.rescan();
                    check("title.kerning", held && t.track < entryTrack, { entry: entryTrack, now: t.track, p: t.pressureNow });
                    // It crossed once before the room was entered again, and again after: the session remembers both.
                    check("title.phase", t.instrument && t.crossings === 2, { p: t.pressureNow, instrument: t.instrument, crossings: t.crossings });
                    after(root.gpu ? 2500 : 1200, () => {
                        check("title.front", t.settled && t.shown.every(s => s), { shown: t.shown });
                        if (root.gpu) {
                            const windows = Strata.live.includes("panel:title.counters") ? root.find(t, i => i.found !== undefined && i.glyphs !== undefined) : null;
                            check("title.counters", windows && windows.found >= 1, { found: windows?.found, live: Strata.live });
                        }
                        shot("instrument", () => {
                            // Back below the threshold, but not below where it turns back: it stays an instrument.
                            root.rows = 22;
                            after(100, () => {
                                t.rescan();
                                const stays = t.instrument;
                                root.rows = 3;
                                after(100, () => {
                                    t.rescan();
                                    check("title.hysteresis", stays && !t.instrument && t.pressureNow < 0.58, { stays: stays, p: t.pressureNow });
                                    after(1200, () => {
                                        check("title.editorial", t.settled && t.shown.every(s => !s), { shown: t.shown });
                                        overdrive(false);
                                        after(300, () => {
                                            check("title.release", !layer().item && title().nameOpacity === 1 && !Strata.live.some(n => n.includes("title.") || n.includes("sheet.")) && sheet.swell === 0,
                                                  { item: !!layer().item, opacity: title().nameOpacity, live: Strata.live });
                                            traced.active = true;
                                            after(2500, () => {
                                                const m = traced.item;
                                                const runs = m.runs.length, found = m.found;
                                                // A resize repaints the canvas; the counters it found must survive it.
                                                m.width = 300;
                                                after(150, () => {
                                                    check("title.mask", found === 1 && runs > 10 && m.runs.length === runs && m.runsW === 180,
                                                          { found: found, runs: runs, after: m.runs.length, runsW: m.runsW, maskW: m.maskW });
                                                    finish();
                                                });
                                            });
                                        });
                                    });
                                });
                            });
                        });
                    });
                });
            });
        });
    });
    function finish() {
        console.log("CUE_ACTIVE", Motion.active, JSON.stringify(Motion.activeNames));
        console.log("CUE_DONE");
        Qt.exit(0);
    }
}
