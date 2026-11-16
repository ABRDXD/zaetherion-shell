import QtQuick
import Quickshell
import qs.adapters.fixture
import qs.core.client
import qs.view.shell
import qs.view.rooms
import qs.view.ui as UI
import qs.view.cues

// Workspaces as an orbit (Z209), offscreen on the fixture's desks: the current desk sits at the front; hover looks
// without turning the ring; a click switches; Move carries the window chosen at the press even while looking
// elsewhere; the ring turns the short way; an empty desk says so; Silent is still and Overdrive drifts the moons.
// With WORKSPACES_SHOTS set, frames are saved there.
Scope {
    id: test
    readonly property string shots: Quickshell.env("WORKSPACES_SHOTS") || ""
    CoreClient { id: core; path: "" }
    FixtureAdapter { id: host }
    ShellContext { id: shell; core: core; panelOpen: true }
    FloatingWindow {
        implicitWidth: 1100; implicitHeight: 640; visible: true
        color: UI.Design.background
        Item {
            id: stage; anchors.fill: parent
            Rectangle { anchors.fill: parent; color: UI.Design.background }
            Workspaces { id: room; anchors.fill: parent; anchors.margins: 30; host: host; shell: shell; historyOverride: ({ memories: { "5": { at: 0, rects: [] } } }) }
        }
    }
    readonly property var wm: host.workspaces
    function check(name, ok, detail) { ok ? console.log("CUE_PASS", name) : console.log("CUE_FAIL", name, JSON.stringify(detail ?? {})); }
    function shot(name) { if (test.shots) stage.grabToImage(r => r.saveToFile(test.shots + "/" + name + ".png")); }
    function planets(from) {
        const out = [];
        const walk = i => { if (!i) return; if (i.remembered !== undefined && i.front !== undefined) out.push(i); for (const c of i.children ?? []) walk(c); };
        walk(from ?? room);
        return out;
    }
    function win(id, app, title, desk, x, w, focused) {
        return { id: id, appId: app, title: title, workspaceId: desk, monitor: "FIXTURE-1", x: x, y: 48, width: w, height: 1032,
                 floating: false, fullscreen: false, focused: focused };
    }
    function lastCall() { return wm.calls[wm.calls.length - 1] ?? null; }
    Component.onCompleted: {
        UI.Design.source = host.palette;
        wm.activeId = "3";
        wm.windows = [win("0xa", "kitty", "claude · zaetherion-shell", "3", 0, 1180, true), win("0xb", "firefox", "launcher looks", "3", 1180, 740, false),
                      win("0xc", "codium", "FluidTasks.qml", "2", 0, 1280, false), win("0xd", "kitty", "tests", "2", 1280, 640, false),
                      win("0xe", "spotify", "Cö shu Nie", "4", 0, 1920, false)];
        Motion.reduced = false; Motion.overdrive = false; Motion.seen = true;
    }
    property int step: 0
    Timer {
        interval: 600; running: true; repeat: true
        onTriggered: {
            const s = test.step++;
            if (s === 0) {
                const front = test.planets().filter(p => p.front);
                test.check("front.is.current", front.length === 1 && front[0].number === 3, front.map(p => p.number));
                test.check("summary.reads", room.inspectedWindows.length === 2 && room.selectedWindow.id === "0xa");
                test.check("silent.still", Motion.idleLoops === 0, Motion.idleLoops);
                test.shot("here");
                const turn = room.turnTarget;
                room.looking = 2;
                test.check("look.keeps.ring", room.turnTarget === turn && room.inspected === 2 && room.inspectedWindows.length === 2);
            } else if (s === 1) {
                test.shot("looking");
                room.picked = 1;
                test.check("pick.selects", room.selectedWindow.id === "0xd");
                room.carried = room.selectedWindow;
                room.looking = 4;
                test.check("move.survives.look", room.carried.id === "0xd" && room.moving);
                test.shot("moving");
                room.go(4);
                const c = test.lastCall();
                test.check("move.carries", c && c.method === "moveWindow" && c.args[0] === "0xd" && c.args[1] === "4" && !room.moving, c);
            } else if (s === 2) {
                room.looking = 0;
                room.go(5);
                const c = test.lastCall();
                test.check("go.switches", c && c.method === "switchTo" && c.args[0] === "5", c);
                room.looking = 5;
                test.check("empty.says.so", room.inspectedWindows.length === 0 && room.selectedWindow === null);
                test.check("remembered.shell", test.planets().find(p => p.number === 5).remembered === true);
                room.looking = 0;
                const before = room.turnTarget;
                wm.activeId = String(room.count);
                test.check("turns.short.way", Math.abs(room.turnTarget - before) <= room.count / 2 && ((room.turnTarget % room.count) + room.count) % room.count === room.count - 1,
                           { before: before, after: room.turnTarget });
            } else if (s === 4) {
                wm.activeId = "3";
                Motion.overdrive = true;
            } else if (s === 6) {
                test.check("overdrive.drifts", Motion.idleLoops > 0, Motion.idleLoops);
                test.shot("overdrive");
                Motion.overdrive = false;
            } else if (s === 9) {
                test.check("release.still", Motion.idleLoops === 0, Motion.idleLoops);
                console.log("CUE_DONE"); Qt.quit();
            }
        }
    }
}
