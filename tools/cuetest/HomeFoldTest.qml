import QtQuick
import Quickshell
import qs.adapters.fixture
import qs.core.client
import qs.view.cues
import qs.view.rooms
import qs.view.shell
import qs.view.strata
import qs.view.ui
import "view/rooms/DayFold.js" as Fold
import "view/rooms/DayTime.js" as T

// Home folded by the day and set as an edition (view/rooms/DayFoldSheet.qml, Home's Today strip; docs/OVERDRIVE.md §36,
// atlas #9, #11), in the real room with a synthetic sky. Silent: TODAY, the cards in their order, no sheet. Overdrive:
// a crease pressed where the day is, the edition and its first printing, the front page with the lead set wide; opened
// again in the same minute, the same crease is pressed again (the second printing); the rooms used today move to the
// front; a release is Silent's Home again. With HOME_SHOTS set, a frame.
Scope {
    id: root
    function check(name, ok, detail) { ok ? console.log("CUE_PASS", name) : console.log("CUE_FAIL", name, JSON.stringify(detail ?? {})); }
    function after(ms, fn) {
        const timer = Qt.createQmlObject("import QtQuick; Timer {}", root);
        timer.interval = ms;
        timer.triggered.connect(() => { timer.destroy(); fn(); });
        timer.start();
    }
    function find(item, test) {
        if (!item) return null;
        if (test(item)) return item;
        for (const child of item.children ?? []) {
            const found = find(child, test);
            if (found) return found;
        }
        return null;
    }
    readonly property string shots: Quickshell.env("HOME_SHOTS") || ""
    function shot(name, fn) {
        if (!shots) { fn(); return; }
        stage.grabToImage(r => { r.saveToFile(shots + "/" + name + ".png"); fn(); });
    }
    CoreClient { id: core }
    FixtureAdapter { id: fixture }
    ShellContext { id: context; panelOpen: true; core: core }
    FloatingWindow {
        id: window
        implicitWidth: 1100; implicitHeight: 760; visible: true
        color: "#0d1218"
        Item {
            id: stage
            anchors.fill: parent
            Rectangle { anchors.fill: parent; color: "#0d1218" }
            Home { id: room; x: 24; y: 24; width: parent.width - 48; height: parent.height - 48; host: fixture; shell: context; core: core }
        }
    }
    function iso(h) { const d = new Date(); d.setHours(Math.floor(h), Math.round(h % 1 * 60), 0, 0); return d.toISOString(); }
    function masthead() { return find(room, i => typeof i.text === "string" && (i.text === "TODAY" || i.text.includes("EDITION") || i.text.startsWith("LATE FINAL"))); }
    function cards() {
        const row = find(room, i => i.children && i.children.length >= 4 && i.children.filter(c => c.modelData?.room !== undefined).length === 4);
        return row ? row.children.filter(c => c.modelData?.room !== undefined).sort((a, b) => a.x - b.x) : [];
    }
    function sheet() { return find(stage, i => i.folds !== undefined && i.nowX !== undefined); }
    function hour() { const d = new Date(); return d.getHours() + d.getMinutes() / 60; }
    Component.onCompleted: after(400, () => {
        const sky = find(room, i => i.lapse !== undefined && i.traced !== undefined);
        sky.sky = { at: new Date().toISOString(), sidereal: 52.5, sun: { rise: iso(6.5), set: iso(18.25) }, bodies: {}, moon: { illumination: 0.4 } };
        after(150, () => {
            const order = cards().map(c => c.modelData.room);
            check("fold.silent", masthead()?.text === "TODAY" && !Strata.live.includes("panel:home.fold") && !sheet()
                  && JSON.stringify(order) === JSON.stringify(["tasks", "timers", "notifications", "workspaces"]),
                  { masthead: masthead()?.text, live: Strata.live, order: order });
            Motion.overdrive = true;
            Motion.settleDrive();
            after(400, () => {
                const s = sheet();
                const edition = Fold.edition(hour(), 6.5, (6.5 + 18.25) / 2, 18.25);
                const ruler = find(room, i => i.lineY !== undefined && i.misregistered !== undefined);
                const at = ruler.mapToItem(room, 0, 0);
                const placed = s ? Math.abs(s.folds[0].x * room.width - (at.x + ruler.width * T.x(hour(), 6.5, 18.25))) < 2 : false;
                check("fold.pressed", !!s && Strata.live.includes("panel:home.fold") && s.folds.length === 1 && placed && s.parent?.parent === stage,
                      { sheet: !!s, folds: s?.folds, live: Strata.live });
                const c = cards();
                check("fold.edition", masthead()?.text === edition + " · 1ST PRINTING" && c[0].modelData.room === room.frontPage[0]
                      && c[0].width > c[1].width * 1.4,
                      { masthead: masthead()?.text, expected: edition, front: room.frontPage, widths: c.map(x => Math.round(x.width)) });
                shot("home-fold", () => {
                    // Opened again (the panel closed and opened), with a day spent in the inbox.
                    core.journeyData = { days: { [Qt.formatDate(new Date(), "yyyy-MM-dd")]: { notifications: 30, tasks: 1 } } };
                    context.panelOpen = false;
                    after(200, () => {
                        context.panelOpen = true;
                        after(400, () => {
                            const again = sheet();
                            check("fold.again", !!again && again.folds.length === 1 && again.sheet.creases[0].n === 2
                                  && masthead()?.text === edition + " · 2ND PRINTING" && room.frontPage[0] === "notifications"
                                  && cards()[0].modelData.room === "notifications",
                                  { folds: again?.sheet?.creases, masthead: masthead()?.text, front: room.frontPage });
                            // The week as a ledger: today inked, the inbox's number on it; the other days blank.
                            const todayIndex = (new Date().getDay() + 6) % 7;
                            const inked = Strata.live.filter(n => n.startsWith("panel:week.ledger."));
                            const mark = find(room, i => typeof i.text === "string" && i.text === "08" && i.font?.pixelSize === Design.caption);
                            check("week.ledger", JSON.stringify(inked) === JSON.stringify(["panel:week.ledger." + todayIndex]) && !!mark?.visible,
                                  { inked: inked, mark: !!mark });
                            shot("home-ledger", () => {
                            Motion.overdrive = false;
                            Motion.settleDrive();
                            after(300, () => {
                                const order = cards().map(c => c.modelData.room);
                                check("fold.release", masthead()?.text === "TODAY" && !sheet() && !Strata.live.includes("panel:home.fold") && !Strata.live.some(n => n.includes("week.ledger"))
                                      && JSON.stringify(order) === JSON.stringify(["tasks", "timers", "notifications", "workspaces"]),
                                      { masthead: masthead()?.text, live: Strata.live, order: order });
                                console.log("CUE_ACTIVE", Motion.active, JSON.stringify(Motion.activeNames));
                                console.log("CUE_DONE");
                                Qt.exit(0);
                            });
                            });
                        });
                    });
                });
            });
        });
    });
}
