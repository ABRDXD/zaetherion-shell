import QtQuick
import Quickshell
import qs.adapters.fixture
import qs.core.client
import qs.view.cues
import qs.view.rooms
import qs.view.shell

// Home's day ruler (view/rooms/DayRuler.qml, docs/OVERDRIVE.md §21) in the real room, with a synthetic sky: Silent
// draws the civil hours with daylight at its fixed share and no sidereal margin; Overdrive adds the sidereal row; a
// misregistered opening shows the solar and sidereal frames beside the civil one; a release returns to Silent's ruler.
// With HOME_SHOTS set, frames are saved there.
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
        implicitWidth: 1100; implicitHeight: 700; visible: true
        color: "#0d1218"
        Item {
            id: stage
            anchors.fill: parent
            Rectangle { anchors.fill: parent; color: "#0d1218" }
            Home { id: room; anchors.fill: parent; anchors.margins: 24; host: fixture; shell: context; core: core }
        }
    }
    function iso(h) { const d = new Date(); d.setHours(Math.floor(h), Math.round(h % 1 * 60), 0, 0); return d.toISOString(); }
    function marks(ruler, test) { return ruler.children.filter(c => c instanceof Rectangle && test(c)); }
    Component.onCompleted: after(400, () => {
        const ruler = find(room, i => i.lineY !== undefined && i.siderealTicks === undefined && i.misregistered !== undefined);
        const sky = find(room, i => i.lapse !== undefined && i.traced !== undefined);
        sky.sky = { at: new Date().toISOString(), sidereal: 52.5, sun: { rise: iso(6.5), set: iso(18.25) }, bodies: {}, moon: { illumination: 0.4 } };
        ruler.misregistered = false;
        after(100, () => {
            const day = find(ruler, i => i instanceof Rectangle && i.height === 3 && Math.abs(i.opacity - 0.7) < 0.01);
            const ticks = ruler.children.filter(c => c.modelData !== undefined && c.modelData.major !== undefined).length;
            const sidereal = ruler.children.filter(c => c.modelData !== undefined && c.modelData.k !== undefined).length;
            check("ruler.silent", ticks === 25 && !!day && Math.abs(day.width - 0.6 * ruler.width) < 1 && sidereal === 0,
                  { ticks: ticks, day: day?.width, width: ruler.width, sidereal: sidereal });
            shot("home-silent", () => {
                Motion.overdrive = true;
                Motion.settleDrive();
                after(100, () => {
                    const k = ruler.children.filter(c => c.modelData !== undefined && c.modelData.k !== undefined);
                    const label = find(ruler, i => typeof i.text === "string" && i.text.startsWith("SIDEREAL "));
                    const frames = ruler.children.filter(c => c.modelData !== undefined && c.modelData.frame !== undefined).map(c => c.modelData.frame);
                    check("ruler.overdrive", k.length === 24 && !!label && label.visible && JSON.stringify(frames) === JSON.stringify(["SOLAR", "SIDEREAL"]),
                          { sidereal: k.length, label: label?.text, frames: frames });
                    shot("home-overdrive", () => {
                        Motion.overdrive = false;
                        Motion.settleDrive();
                        ruler.misregistered = true;
                        after(100, () => {
                            const frames = ruler.children.filter(c => c.modelData !== undefined && c.modelData.frame !== undefined).length;
                            const sidereal = ruler.children.filter(c => c.modelData !== undefined && c.modelData.k !== undefined).length;
                            check("ruler.misregistered", frames === 2 && sidereal === 0, { frames: frames, sidereal: sidereal });
                            ruler.misregistered = false;
                            ruler.journey = { hours: { tasks: Array.from({ length: 24 }, (_, h) => h === 9 ? 1 : 0.1) }, visits: { tasks: 9 } };
                            after(50, () => {
                                const windows = ruler.children.filter(c => c.modelData !== undefined && c.modelData.room !== undefined);
                                check("ruler.recurrence", windows.length === 1 && Math.abs(windows[0].x - (ruler.px(9) + 1)) < 0.5, { windows: windows.length });
                                ruler.journey = null;
                                const none = ruler.children.filter(c => c.modelData !== undefined && (c.modelData.frame !== undefined || c.modelData.k !== undefined)).length;
                                check("ruler.release", none === 0, { left: none });
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
}
