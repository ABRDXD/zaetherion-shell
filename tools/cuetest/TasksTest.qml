import QtQuick
import Quickshell
import qs.view.cues
import qs.view.rooms

// Task rows' patina and cut-outs (view/rooms/TaskRow.qml; atlas #25, #26): clean on time; one ghost from a day late;
// the rule doubled from three; a second ghost from ten; a task finished today an empty cut-out that takes no input and
// shows when it went. Nothing animates.
Scope {
    id: root
    function check(name, ok, detail) { ok ? console.log("CUE_PASS", name) : console.log("CUE_FAIL", name, JSON.stringify(detail ?? {})); }
    function after(ms, fn) {
        const timer = Qt.createQmlObject("import QtQuick; Timer {}", root);
        timer.interval = ms;
        timer.triggered.connect(() => { timer.destroy(); fn(); });
        timer.start();
    }
    function day(offset) { const d = new Date(today); d.setDate(d.getDate() + offset); return Qt.formatDate(d, "yyyy-MM-dd"); }
    readonly property date today: new Date(2026, 10, 9, 12, 0)
    FloatingWindow {
        id: window
        implicitWidth: 760; implicitHeight: 420; visible: true
        Column {
            width: parent.width
            TaskRow { id: fresh; width: parent.width; number: 1; today: root.today; task: ({ id: "a", text: "On time", done: false, due: root.day(2) }) }
            TaskRow { id: late4; width: parent.width; number: 2; today: root.today; task: ({ id: "b", text: "Four days late", done: false, due: root.day(-4) }) }
            TaskRow { id: late12; width: parent.width; number: 3; today: root.today; task: ({ id: "c", text: "Twelve days late", done: false, due: root.day(-12) }) }
            TaskRow { id: gone; width: parent.width; number: 0; today: root.today; vanished: true
                      task: ({ id: "d", text: "Finished this morning", done: true, due: null, doneAt: new Date(2026, 10, 9, 9, 42).getTime() }) }
        }
    }
    function find(item, test) {
        if (!item) return null;
        if (test(item)) return item;
        for (const child of item.children ?? []) { const f = find(child, test); if (f) return f; }
        return null;
    }
    function visibleCopies(row) {
        const body = find(row, i => i.text === row.task.text && i.z === 0 && i.font !== undefined && i.wrapMode !== undefined && i.parent && i.parent.spacing !== undefined);
        return body ? body.children.filter(c => c.visible && c.text === row.task.text).length : -1;
    }
    function rules(row) { return row.children.filter(c => c.node !== undefined && c.visible).length; }
    Component.onCompleted: after(300, () => {
        check("tasks.patina", visibleCopies(fresh) === 0 && rules(fresh) === 1 && visibleCopies(late4) === 1 && rules(late4) === 2
              && visibleCopies(late12) === 2 && late12.shift > late4.shift,
              { fresh: [visibleCopies(fresh), rules(fresh)], late4: [visibleCopies(late4), rules(late4)], late12: [visibleCopies(late12), rules(late12)] });
        const row = gone.children.find(c => c.spacing !== undefined);
        const label = find(gone, i => typeof i.text === "string" && i.text.startsWith("DONE "));
        check("tasks.cutout", !!row && row.opacity === 0 && !row.enabled && !gone.hot && label?.visible && label.text === "DONE 09:42" && gone.patina === 0,
              { opacity: row?.opacity, enabled: row?.enabled, label: label?.text });
        console.log("CUE_ACTIVE", Motion.active, JSON.stringify(Motion.activeNames));
        console.log("CUE_DONE");
        Qt.exit(0);
    });
}
