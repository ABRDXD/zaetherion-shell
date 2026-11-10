import QtQuick
import Quickshell
import qs.adapters.fixture
import qs.core.client
import qs.view.shell
import qs.view.rooms
import qs.view.ui as UI
import qs.view.cues

// Sessions in the Timers room (M11, view/rooms/Timers.qml and SessionDebrief.qml), offscreen, on snapshots written
// straight into the client as the core would publish them: no session (the presets and the streak), one running
// (its clock, the end button, no presets) and the debrief after (planned and done, tasks, the host's apps). Nothing
// is sent to a core. With SESSION_SHOTS set, frames are saved there.
Scope {
    id: root
    readonly property string shots: Quickshell.env("SESSION_SHOTS") || ""
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
    function all(item, test, out) {
        out = out ?? [];
        if (!item) return out;
        if (test(item)) out.push(item);
        for (const c of item.children ?? []) all(c, test, out);
        return out;
    }
    function shown(item) {
        for (let p = item; p; p = p.parent) if (!p.visible) return false;
        return true;
    }
    function buttons() { return all(room, i => i.label !== undefined && i.primary !== undefined && shown(i)).map(b => b.label); }
    CoreClient { id: core; path: "" }
    FixtureAdapter { id: host }
    ShellContext { id: shell; core: core; panelOpen: true }
    readonly property var presets: [{ name: "focus", seconds: 3000 }, { name: "deep", seconds: 5400 }, { name: "study", seconds: 7200 }, { name: "read", seconds: 2700 }]
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
    Component.onCompleted: after(300, () => {
        ViewState.timerKind = "session";
        core.sessionData = { active: null, last: null, presets: root.presets, streak: root.streak };
        after(300, () => {
            const card = find(room, i => i.debrief !== undefined && i.streak !== undefined && i.dismissed !== undefined);
            const b = buttons();
            check("session.idle", !!card && card.visible && b.includes("focus 50 min") && b.includes("study 2 h") && !b.includes("End session") && !b.includes("Start"),
                  { card: !!card, buttons: b });
            shot("idle", () => {
                const now = Date.now();
                core.sessionData = { active: { preset: "focus", startedAt: now - 600000, until: now + 2400000, seconds: 3000 }, last: null, presets: root.presets, streak: root.streak };
                after(1300, () => {
                    const b2 = buttons();
                    const clock = find(room, i => i.objectName === "temporal-clock");
                    check("session.running", b2.includes("End session") && !b2.includes("focus 50 min") && room.running && room.sources.some(s => s.kind === "session")
                          && /^(39|40):\d\d$/.test(clock?.text ?? "") && card.debrief === null, { buttons: b2, clock: clock?.text });
                    shot("running", () => {
                        core.sessionData = { active: null, presets: root.presets, streak: root.streak,
                            last: { preset: "focus", start: now - 3000000, end: now, seconds: 2400, planned: 3000, completed: false, tasks: 2,
                                    apps: [["code", 1500], ["firefox", 600], ["kitty", 240]] } };
                        after(300, () => {
                            const bars = all(card, i => i.objectName === "session-app" && shown(i));
                            check("session.debrief", card.visible && card.debrief !== null && bars.length === 3 && buttons().includes("focus 50 min"),
                                  { bars: bars.length, buttons: buttons() });
                            shot("debrief", () => {
                                core.sessionData = { active: null, presets: root.presets, streak: root.streak,
                                    last: { preset: "read", start: now - 120000, end: now, seconds: 120, planned: 2700, completed: false, tasks: 0 } };
                                after(200, () => {
                                    check("session.restarted", card.visible && all(card, i => i.objectName === "session-app" && shown(i)).length === 0);
                                    ViewState.timerKind = "countdown";
                                    after(100, () => {
                                        check("session.other.tabs", !card.visible && buttons().includes("Start"));
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
    })
}
