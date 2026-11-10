import QtQuick
import Quickshell
import qs.core.client
import qs.view.contract

// The mirror is the core's (busctl monitor, 24 h persistence); DND and the host centre stay host-side.
NotificationsDomain {
    id: root
    required property var settings
    required property CoreClient core
    readonly property var mirror: core.notificationsData
    available: core.connected && (mirror?.available ?? false)
    items: available ? mirror.items : []
    unread: available ? mirror.unread : 0
    dnd: settings.values.notifications?.dnd === true

    function setDnd(on: bool) { if (on !== dnd) Quickshell.execDetached(["serpantinum", "set", "notifications", "dnd", "toggle"]); }
    function markAllRead() { core.request("notif.markAllRead"); }
    function dismiss(id: string) { core.request("notif.dismiss", { id: id }); }
    function openHost() { Quickshell.execDetached(["serpantinum", "msg", "open", "notifications"]); }
}
