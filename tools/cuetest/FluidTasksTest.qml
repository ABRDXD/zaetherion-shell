import QtQuick
import Quickshell
import qs.adapters.fixture
import qs.core.client
import qs.view.shell
import qs.view.rooms
import qs.view.contract
import qs.view.ui as UI
import qs.view.cues

// Confluence Tasks (view/fluid/FluidTasks.qml, TasksAtlas.qml), offscreen on a fake core's task lists: the late task
// burns warm at the core, sooner tasks sit nearer the centre, today's finished task is hollow, the next task and the
// open count read right, the lists show as constellations, the entry line reads through the controller, typing marks
// the room as editing, and Angular keeps the sheet. With FLUID_TASKS_SHOTS set, frames are saved there.
Scope {
    id: root
    readonly property string shots: Quickshell.env("FLUID_TASKS_SHOTS") || ""
    function check(name, ok, detail) { ok ? console.log("CUE_PASS", name) : console.log("CUE_FAIL", name, JSON.stringify(detail ?? {})); }
    function after(ms, fn) {
        const timer = Qt.createQmlObject("import QtQuick; Timer {}", root);
        timer.interval = ms;
        timer.triggered.connect(() => { timer.destroy(); fn(); });
        timer.start();
    }
    function shot(name, then) {
        if (!root.shots) { then(); return; }
        stage.grabToImage(r => { r.saveToFile(root.shots + "/" + name + ".png"); then(); });
    }
    function named(name, from) {
        const walk = i => { if (!i) return null; if (i.objectName === name) return i; for (const c of i.children ?? []) { const f = walk(c); if (f) return f; } return null; };
        return walk(from ?? room.presentation.item);
    }
    function day(n) {
        const d = new Date(); d.setDate(d.getDate() + n);
        return d.getFullYear() + "-" + String(d.getMonth() + 1).padStart(2, "0") + "-" + String(d.getDate()).padStart(2, "0");
    }
    function centre(id) {
        const s = named("tasksStar." + id), atlas = named("tasks.atlas");
        return s ? Math.hypot(s.x - atlas.cx, (s.y - atlas.cy) / 0.5) : -1;
    }
    CoreClient { id: core; path: "" }
    FixtureAdapter { id: fixture }
    ShellContext { id: context; panelOpen: true; core: core }
    PaletteDomain {
        id: larimar
        available: true
        colors: ({ background: "#000000", surface: "#0a181c", surfaceRaised: "#152d36", text: "#e6f9fc", textMuted: "#a0dbe6",
                   textFaint: "#589dbb", line: "#20424f", accent: "#42c8d9", warm: "#f9e2af", danger: "#b4befe",
                   highlight: "#42c8d9", success: "#94e2d5", islandBackground: "#071114" })
    }
    FloatingWindow {
        implicitWidth: 1360; implicitHeight: 860; visible: true; color: "#000000"
        Item {
            id: stage; anchors.fill: parent
            Rectangle { anchors.fill: parent; color: "#000000" }
            Tasks { id: room; anchors.fill: parent; anchors.margins: 30; host: fixture; shell: context; core: core }
        }
    }
    Component.onCompleted: {
        UI.Design.source = larimar;
        UI.Design.form = "fluid";
        ViewState.taskList = "default";
        ViewState.taskFilter = "active";
        ViewState.taskDraft = "";
        core.connected = true;
        core.tasksData = {
            lists: [{ id: "default", name: "Tasks" }, { id: "work", name: "Work" }, { id: "home", name: "Home" }],
            tasks: [
                { id: "t1", list: "default", text: "Renew the passport", done: false, due: root.day(-2) },
                { id: "t2", list: "default", text: "Send the invoice", done: false, due: root.day(0) },
                { id: "t3", list: "default", text: "Book the dentist", done: false, due: root.day(3) },
                { id: "t4", list: "default", text: "Back up the photos", done: false, due: root.day(20) },
                { id: "t5", list: "default", text: "Fix the bike light", done: false, due: root.day(70) },
                { id: "t6", list: "default", text: "Learn the fiddle", done: false, due: null },
                { id: "t7", list: "default", text: "Water the plants", done: true, due: root.day(0), doneAt: Date.now() },
                { id: "w1", list: "work", text: "Review the draft", done: false, due: root.day(1) },
                { id: "h1", list: "home", text: "Groceries", done: false, due: null },
                { id: "h2", list: "home", text: "Call the landlord", done: false, due: root.day(2) }
            ]
        };
        after(1200, () => {
            check("fluid.presented", !!named("tasks.atlas"), {});
            check("open.count", named("tasks.open").text === "06", named("tasks.open")?.text);
            const order = ["t1", "t2", "t3", "t4", "t5", "t6"].map(root.centre);
            check("sooner.is.nearer", order.every((d, i) => i === 0 || d > order[i - 1]), order.map(Math.round));
            const late = named("tasksStarBody", named("tasksStar.t1"));
            check("late.burns.warm", String(late.color).toLowerCase() !== String(UI.Design.coldStar).toLowerCase() && late.color.b < late.color.r, String(late.color));
            const done = named("tasksStarBody", named("tasksStar.t7"));
            check("done.is.hollow", !!done && done.hollow && done.border.width > 0, {});
            check("next.is.the.late.one", named("tasks.next").text === "Renew the passport", named("tasks.next").text);
            check("route.drawn", named("tasksRoute").visible, {});
            check("lists.as.constellations", !!named("tasks.list.work") && !!named("tasks.list.home"), {});
            room.controller.setDraft("call the bank @home !fri");
            after(100, () => {
                check("entry.reads", room.controller.entryHint.indexOf("Home") > 0 && room.controller.canAdd, room.controller.entryHint);
                named("tasks.entry").forceActiveFocus();
                check("editing.follows.focus", room.editing === true, room.editing);
                root.shot("fluid-tasks", () => {
                    ViewState.taskList = "home";
                    after(300, () => {
                        check("switch.list", named("tasks.open").text === "02" && !!named("tasksStar.h1"), named("tasks.open").text);
                        UI.Design.form = "angular";
                        after(600, () => {
                            check("angular.keeps.sheet", !named("tasks.atlas") && room.controller.remaining === 2, room.controller.remaining);
                            console.log("CUE_DONE");
                            Qt.quit();
                        });
                    });
                });
            });
        });
    }
}
