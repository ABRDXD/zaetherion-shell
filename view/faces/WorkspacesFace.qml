import qs.view.contract
import QtQuick

// Workspaces as a planet: the desk you are on, and how many windows it and the others hold. The
// compositor's own state; no lease.
Face {
    id: root
    required property HostAdapter host
    readonly property var wm: host.workspaces
    readonly property int desk: Number(wm.activeId) || 1
    readonly property int here: wm.windows.filter(w => Number(w.workspaceId) === desk).length
    readonly property int busy: new Set(wm.windows.map(w => Number(w.workspaceId))).size

    figure: String(desk).padStart(2, "0")
    brief: "DESK " + desk
    note: here === 0 ? "EMPTY" : here + (here === 1 ? " WINDOW" : " WINDOWS")
    detail: wm.windows.length + " WINDOWS · " + busy + (busy === 1 ? " DESK" : " DESKS") + " IN USE"

    Accessible.role: Accessible.StaticText
    Accessible.name: "Desk " + desk + ", " + note.toLowerCase()
}
