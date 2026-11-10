import QtQuick
import Quickshell
import qs.adapters.fixture
import qs.core.client
import qs.view.cues
import qs.view.satellites

// Satellites (DAILY_DRIVER §5, §7): each kind loads only while due and unloads after, minute-resolution
// wakeups, the DONE flash through FlashGate (static when reduced), suppression by the panel, a
// fullscreen window and a session, and zero surfaces when idle. Topic snapshots are written straight
// into an unconnected CoreClient; the offscreen platform has no layer shell, so the surface is a
// FloatingWindow.
ShellRoot {
    id: root
    property double fakeNow: 1000000000000
    function check(name, ok, detail) { ok ? console.log("CUE_PASS", name) : console.log("CUE_FAIL", name, JSON.stringify(detail ?? {})); }
    function after(ms, fn) {
        const timer = Qt.createQmlObject("import QtQuick; Timer {}", root);
        timer.interval = ms;
        timer.triggered.connect(() => { timer.destroy(); fn(); });
        timer.start();
    }
    function timers(countdown, pomodoro) {
        return { at: fakeNow, sound: false, config: { pomodoro: { focus: 1500, break: 300, longBreak: 900, cycles: 4 } },
                 countdown: Object.assign({ running: false, elapsed: 0, duration: 0, done: null }, countdown ?? {}),
                 pomodoro: Object.assign({ running: false, phase: "focus", cycle: 0, elapsed: 0, duration: 1500, done: null }, pomodoro ?? {}),
                 stopwatch: { running: false, elapsed: 0, laps: [] } };
    }
    function idle() { return sats.surfaces === 0 && sats.shown.length === 0 && !sats.state.wake.running && !sats.state.dwell.running; }
    function setTrack(title) {
        fixture.media.active = Object.assign({}, fixture.media.active, { title: title });
    }

    FixtureAdapter { id: fixture }
    CoreClient { id: core; path: "" }
    Satellites {
        id: sats
        core: core
        host: fixture
        surface: Component { FloatingWindow { implicitWidth: 300; implicitHeight: 200; color: "transparent" } }
    }
    Component.onCompleted: {
        Motion.timeScale = 0.1;
        sats.state.clock = () => root.fakeNow;
        FlashGate.now = () => root.fakeNow;
        const steps = [
            () => check("sat.idle.none", idle(), { surfaces: sats.surfaces, shown: sats.shown }),
            () => {
                core.timersData = timers({ running: true, duration: 1500 });
                check("sat.timer.minutes", sats.shown.join() === "timer" && sats.state.timerText === "25′" && sats.state.nextChange === 60000 && sats.surfaces === 1,
                      { shown: sats.shown, text: sats.state.timerText, next: sats.state.nextChange });
            },
            () => {
                core.timersData = timers({ running: true, duration: 1500, elapsed: 1438.5 });
                const a = [sats.state.timerText, sats.state.nextChange];
                core.timersData = timers({ running: true, duration: 1500, elapsed: 1469.8 });
                const b = [sats.state.timerText, sats.state.nextChange];
                check("sat.timer.last.minute", a[0] === "2′" && a[1] === 1500 && b[0] === "0:31" && b[1] === 200, { a: a, b: b });
            },
            () => {
                core.timersData = timers({ running: true, duration: 1500 });
                sats.panelOpen = true;
                const panel = sats.shown.length === 0;
                sats.panelOpen = false;
                fixture.workspaces.windows = fixture.workspaces.windows.map(w => Object.assign({}, w, { fullscreen: true, monitor: fixture.workspaces.focusedScreen }));
                const full = sats.shown.length === 0;
                fixture.workspaces.windows = fixture.workspaces.windows.map(w => Object.assign({}, w, { fullscreen: false }));
                check("sat.suppressed", panel && full && sats.shown.join() === "timer", { panel: panel, full: full, shown: sats.shown });
            },
            () => {
                core.timersData = timers({ running: false, duration: 1500, elapsed: 1500, done: { at: fakeNow } });
                fakeNow += 2000;
                const granted = FlashGate.grants.length;
                after(20, () => check("sat.done.flash", sats.shown.join() === "done" && granted === 1, { shown: sats.shown, grants: granted }));
            },
            () => {
                core.timersData = timers();
                check("sat.done.unload", idle(), { shown: sats.shown });
            },
            () => {
                Motion.reduced = true;
                fakeNow += 2000;
                core.timersData = timers({ done: { at: fakeNow } });
                const granted = FlashGate.grants.filter(g => fakeNow - g < 1000).length;
                core.timersData = timers();
                Motion.reduced = false;
                check("sat.done.reduced.static", granted === 0, { granted: granted });
            },
            () => {
                core.timersData = timers({}, { running: true, phase: "break", duration: 300, done: { phase: "focus", next: "break", at: fakeNow, late: false } });
                const shown = sats.shown.join(), text = sats.state.doneText;
                // The core clears it on timer.ack; the snapshot that follows is what the view shows.
                core.timersData = timers({}, { running: true, phase: "break", duration: 300 });
                check("sat.pomodoro.phase.done", shown === "timer,done" && text === "FOCUS DONE" && sats.shown.join() === "timer", { shown: shown, text: text, after: sats.shown });
                core.timersData = timers();
            },
            () => {
                setTrack("Second Signal");
                const shown = sats.shown.join(), text = sats.state.trackText;
                after(Motion.dwell + 100, () => {
                    check("sat.track.dwell", shown === "track" && text === "Test Pattern — Second Signal" && idle(), { shown: shown, text: text, after: sats.shown });
                    root.next();
                });
                return true;
            },
            () => {
                core.sessionData = { active: { preset: "pyq", startedAt: fakeNow, until: fakeNow + 7200000 } };
                setTrack("Third Signal");
                const shown = sats.shown.join();
                core.sessionData = { active: null };
                after(Motion.dwell + 100, () => {
                    check("sat.track.session", shown === "timer" && idle(), { shown: shown });
                    root.next();
                });
                return true;
            },
            // The core's track topic: a fresh change shows (also right after the core spawned this view),
            // a snapshot older than dwell does not, and the adapter reporting the same track adds nothing.
            () => {
                core.trackData = { player: "fixture", artist: "Core Artist", title: "Old News", at: fakeNow - 60000 };
                const old = sats.shown.length === 0;
                core.trackData = { player: "fixture", artist: "Test Pattern", title: "Fourth Signal", at: fakeNow };
                const fresh = sats.shown.join() === "track" && sats.state.trackText === "Test Pattern — Fourth Signal";
                setTrack("Fourth Signal");
                const once = sats.state.trackText === "Test Pattern — Fourth Signal";
                after(Motion.dwell + 100, () => {
                    check("sat.track.core", old && fresh && once && idle(), { old: old, fresh: fresh, once: once, after: sats.shown });
                    root.next();
                });
                return true;
            },
            () => after(200, () => {
                check("sat.idle.end", idle() && Motion.active === 0, { shown: sats.shown, active: Motion.activeNames });
                root.next();
            }) || true,
        ];
        root.steps = steps;
        next();
    }
    property var steps: []
    // A step that returns true calls next() itself; the others run one per 30 ms.
    function next() {
        const step = steps.shift();
        if (!step) {
            console.log("CUE_ACTIVE", Motion.active, JSON.stringify(Motion.activeNames));
            console.log("CUE_DONE");
            Qt.quit();
            return;
        }
        if (!step()) after(30, next);
    }
}
