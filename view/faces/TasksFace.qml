import qs.core.client
import QtQuick
import "../rooms/TaskEntry.js" as TaskEntry

// Tasks as a planet: how many lines are open across every list, what is late (the alarm, stated, not
// scolded) or due today; the readout adds the lists and the done count. Due dates are read against
// the day the face was last made live; no timer.
Face {
    id: root
    required property CoreClient core
    property date today: new Date()
    onLiveChanged: if (live) today = new Date()

    readonly property bool available: core.tasks.available
    readonly property var all: core.tasks.all
    readonly property var open: all.filter(t => !t.done)
    readonly property int late: open.filter(t => TaskEntry.state(t.due, today) === "overdue").length
    readonly property int dueToday: open.filter(t => TaskEntry.state(t.due, today) === "today").length
    readonly property int lists: core.tasks.lists.length

    figure: available ? String(open.length) : "–"
    brief: !available ? "–" : late > 0 ? late + " LATE" : dueToday > 0 ? dueToday + " TODAY" : open.length === 0 ? "CLEAR" : open.length + " OPEN"
    note: !available ? "OFFLINE" : late > 0 ? late + " LATE" : dueToday > 0 ? dueToday + " TODAY" : open.length === 0 ? "CLEAR" : "OPEN"
    detail: !available ? "" : [lists + (lists === 1 ? " LIST" : " LISTS"), late > 0 && dueToday > 0 ? dueToday + " TODAY" : "", (all.length - open.length) + " DONE"].filter(s => s).join(" · ")
    alarm: available && late > 0

    Accessible.role: Accessible.StaticText
    Accessible.name: available ? open.length + " open tasks" + (late > 0 ? ", " + late + " late" : dueToday > 0 ? ", " + dueToday + " due today" : "") : "Tasks offline"
}
