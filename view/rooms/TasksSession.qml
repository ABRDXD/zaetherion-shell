import QtQuick
import qs.core.client
import qs.view.contract
import qs.view.shell
import "TaskEntry.js" as TaskEntry

// One owner for the Tasks room's state and actions, shared by both presentations (Angular's ruled sheet and Fluid's
// star atlas), as TimersSession is for Timers. The draft line lives in ViewState.taskDraft so it survives a swap.
Item {
    id: root
    required property HostAdapter host
    required property ShellContext shell
    required property CoreClient core
    property bool shown: false
    property var removedTask: ViewState.removedTask
    onRemovedTaskChanged: ViewState.removedTask = removedTask
    property string creatureNote: "surveyor asleep. work may proceed."
    // The day the room reads due dates against: refreshed whenever the room is shown, no timer.
    property date today: new Date()
    onShownChanged: if (shown) today = new Date()

    readonly property var lists: core.tasks.lists
    readonly property var list: lists.find(l => l.id === ViewState.taskList) ?? lists[0] ?? ({ id: "default", name: "Tasks" })
    readonly property var all: core.tasks.all
    readonly property var inList: all.filter(t => t.list === list.id)
    readonly property int remaining: inList.filter(t => !t.done).length
    readonly property int finished: inList.length - remaining
    readonly property int overdue: inList.filter(t => !t.done && TaskEntry.state(t.due, today) === "overdue").length
    readonly property int dueToday: inList.filter(t => !t.done && TaskEntry.state(t.due, today) === "today").length
    // The open list keeps today's finished tasks in their places as empty cut-outs (TaskRow.vanished, atlas #26).
    readonly property var visibleTasks: inList.filter(t => ViewState.taskFilter === "all" || (ViewState.taskFilter === "done") === t.done
                                                     || ViewState.taskFilter === "active" && TaskEntry.vanishedToday(t, today))
    // Line numbers count only the tasks still there.
    readonly property var numbers: { let n = 0; return visibleTasks.map(t => ViewState.taskFilter === "active" && t.done ? 0 : ++n); }
    readonly property string draft: ViewState.taskDraft
    readonly property var entry: TaskEntry.parse(draft, today)
    readonly property var entryList: entry.list === null ? list
        : lists.find(l => l.name.toLowerCase() === entry.list.toLowerCase() || l.id === entry.list) ?? null
    readonly property string entryHint: entry.error ? entry.error
        : draft.trim() === "" ? "@LIST  ·  !TODAY  !FRI  !+3D  !2026-11-12"
        : "→ " + (entryList ? entryList.name : "new list " + entry.list)
            + (entry.due ? "  ·  due " + TaskEntry.label(entry.due, today) : "")
    readonly property bool canAdd: entry.text.length > 0 && !entry.error && core.tasks.available

    function openCount(id) {
        return all.filter(t => t.list === id && !t.done).length;
    }
    function setDraft(text) { ViewState.taskDraft = text; }
    function addTask() {
        const parsed = entry;
        if (!parsed.text || parsed.error || !core.tasks.available)
            return;
        const target = entryList;
        if (target) {
            core.tasks.add(parsed.text, target.id, parsed.due);
            ViewState.taskList = target.id;
        } else {
            // "@name" for a list that does not exist yet makes it; the hint line says so first.
            core.tasks.addList(parsed.list, created => {
                core.tasks.add(parsed.text, created.id, parsed.due);
                ViewState.taskList = created.id;
            });
        }
        ViewState.taskDraft = "";
        ViewState.taskFilter = "active";
    }
    function toggle(task) { core.tasks.setDone(task.id, !task.done); }
    function remove(task) { core.tasks.remove(task.id, removed => root.removedTask = removed); }
    function undo() {
        core.tasks.restore(removedTask);
        removedTask = null;
    }
    function focus() {
        shell.engagedTimerKind = "pomodoro";
        core.timers.toggle("pomodoro");
    }
}
