import QtQuick
import Quickshell
import qs.adapters.fixture
import qs.core.client
import qs.view.shell
import qs.view.rooms
import qs.view.ui as UI
import qs.view.cues

// Confluence Timers (view/fluid/FluidTimers.qml), offscreen, on snapshots written straight into the client: the Fluid
// presentation shows when the form is Fluid, its clock and mode picker follow the room's controller, each mode shows
// its own details, a running Session offers its end, and switching back to Angular keeps the controller's state.
// Nothing is sent to a core. With FLUID_TIMERS_SHOTS set, frames are saved there.
Scope {
    id: root
    readonly property string shots: Quickshell.env("FLUID_TIMERS_SHOTS") || ""
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
    function find(item, test) {
        if (!item) return null;
        if (test(item)) return item;
        for (const c of item.children ?? []) { const f = find(c, test); if (f) return f; }
        return null;
    }
    function named(name) { return find(room, i => i.objectName === name); }
    function shown(item) {
        if (!item) return false;
        for (let p = item; p; p = p.parent) if (!p.visible) return false;
        return true;
    }
    CoreClient { id: core; path: "" }
    FixtureAdapter { id: host }
    ShellContext { id: shell; core: core; panelOpen: true }
    readonly property var presets: [{ name: "focus", seconds: 3000 }, { name: "deep", seconds: 5400 }, { name: "study", seconds: 7200 }]
    readonly property var streak: ({ current: 3, best: 6, minutes: [0, 50, 90, 0, 0, 120, 50, 45, 0, 5, 60, 120, 90, 50] })
    FloatingWindow {
        implicitWidth: 1100; implicitHeight: 680; visible: true
        color: UI.Design.background
        Item {
            id: stage; anchors.fill: parent
            Rectangle { anchors.fill: parent; color: UI.Design.background }
            Timers { id: room; anchors.fill: parent; anchors.margins: 30; host: host; shell: shell; core: core }
        }
    }
    Component.onCompleted: {
        UI.Design.source = host.palette;
        UI.Design.form = "fluid";
        ViewState.timerKind = "countdown";
        core.sessionData = { active: null, last: null, presets: root.presets, streak: root.streak };
        after(400, () => {
            const clock = named("timers.clock");
            check("fluid.presented", !!named("timers.main") && !!clock && !named("temporal-clock"), { fluid: !!named("timers.main") });
            check("fluid.clock", clock && clock.text === room.controller.stamp(room.controller.seconds), clock?.text);
            const picker = named("timers.modes");
            check("fluid.picker.shown", shown(picker) && picker.width > 200, picker?.width);
            check("fluid.countdown.lengths", shown(named("timers.countdown.25")) && shown(named("timers.addMinute")) && !shown(named("timers.lap")), {});
            check("fluid.glance", ["countdown", "pomodoro", "stopwatch", "session"].every(id => !!named("timers.glance." + id)), {});
            shot("fluid-countdown", () => {
                named("timers.modes").activated(1);
                after(200, () => {
                    check("fluid.mode.picker", ViewState.timerKind === "pomodoro" && named("timers.modes").currentIndex === 1, ViewState.timerKind);
                    check("fluid.focus.details", !shown(named("timers.countdown.25")) && shown(named("timers.toggle")), {});
                    shot("fluid-focus", () => {
                        ViewState.timerKind = "session";
                        after(200, () => {
                            check("fluid.session.ready", named("timers.clock").text === "Ready", named("timers.clock").text);
                            check("fluid.session.presets", shown(named("timers.preset.focus")) && shown(named("timers.preset.study"))
                                  && !shown(named("timers.toggle")) && !shown(named("timers.endSession")), {});
                            shot("fluid-session-idle", () => {
                                const now = Date.now();
                                core.sessionData = { active: { preset: "deep", startedAt: now - 600000, until: now + 4800000, seconds: 5400 },
                                                     last: null, presets: root.presets, streak: root.streak };
                                after(1300, () => {
                                    const c = named("timers.clock");
                                    check("fluid.session.running", shown(named("timers.endSession")) && !named("timers.preset.focus")
                                          && /^79:[0-5]\d$/.test(c.text), { clock: c.text, end: shown(named("timers.endSession")), preset: !!named("timers.preset.focus") });
                                    shot("fluid-session-running", () => {
                                        UI.Design.form = "angular";
                                        after(500, () => {
                                            check("angular.keeps.state", !!named("temporal-clock") && !named("timers.main")
                                                  && ViewState.timerKind === "session" && room.running, {});
                                            UI.Design.form = "fluid";
                                            after(400, () => {
                                                check("fluid.again", !!named("timers.main") && shown(named("timers.endSession")), {});
                                                console.log("CUE_DONE");
                                                Qt.quit();
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
    }
}
