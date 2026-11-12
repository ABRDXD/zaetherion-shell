import QtQuick
import Quickshell
import qs.core.client
import qs.view.contract

// The view reads the core's notification mirror (busctl monitor, 24 h persistence). S4's own notification server
// does not exist yet, so Do-not-disturb has nothing to switch and the host centre is DMS's.
NotificationsDomain {
    id: root
    required property CoreClient core
    readonly property var mirror: core.notificationsData
    available: core.connected && (mirror?.available ?? false)
    items: available ? mirror.items : []
    unread: available ? mirror.unread : 0

    function setDnd(on: bool) { console.warn("dms: Do-not-disturb waits for S4's notification server"); }
    function markAllRead() { core.request("notif.markAllRead"); }
    function dismiss(id: string) { core.request("notif.dismiss", { id: id }); }
    // The session's own bind (Super+Shift+N) runs the same command.
    function openHost() { Quickshell.execDetached(["dms", "ipc", "call", "notifications", "toggle"]); }
}
