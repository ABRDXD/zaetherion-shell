import QtQuick
import Quickshell
import qs.adapters.quickshell
import qs.core.client
import qs.view.contract

// The view reads the core's Inbox, the one list of notifications (Z163). With FART_NOTIFICATION_SERVER=1 it also
// runs our own notification server and reports what that receives to the Inbox; until our server holds the bus
// name the Inbox is filled by the core's mirror of the host's server (DMS's), whose centre stays the host's.
NotificationsDomain {
    id: root
    required property CoreClient core
    property bool serverEnabled: Quickshell.env("FART_NOTIFICATION_SERVER") === "1"
    readonly property var inbox: core.notificationsData
    available: core.connected && (inbox?.available ?? false)
    source: inbox?.source ?? "mirror"
    dnd: inbox?.dnd ?? false
    unread: available ? inbox.unread : 0
    // A picture sent as raw pixels exists only in this process until it is saved: show it from here meanwhile.
    items: !available ? [] : inbox.items.map(item => {
        const picture = item.image === "" ? (server.find(item.id)?.livePicture ?? "") : "";
        return picture === "" ? item : Object.assign({}, item, { image: picture });
    })

    function setDnd(on: bool) { core.request("notif.dnd", { on: on }); }
    function markAllRead() { core.request("notif.markAllRead"); }
    function dismiss(id: string) {
        if (server.find(id)) server.dismiss(id);   // the Inbox hears of it through closed()
        else core.request("notif.dismiss", { id: id });
    }
    function invoke(id: string, action: string, reply: string) {
        if (reply === "") server.invoke(id, action);
        else if (server.reply(id, reply)) server.dismiss(id);
    }
    // The session's own bind (Super+Shift+N) runs the same command.
    function openHost() { Quickshell.execDetached(["dms", "ipc", "call", "notifications", "toggle"]); }

    function ingest(item: QuickshellNotification) { core.request("notif.ingest", item.fields); }
    // Attach to the core, then hand over whatever arrived while it was away.
    function attach() {
        core.request("notif.serve", { ids: server.keys }, (ok, result) => {
            if (!ok) return;
            const known = result.items.map(item => item.id);
            for (const key of server.keys)
                if (!known.includes(key)) ingest(server.find(key));
        });
    }

    readonly property bool attached: serverEnabled && core.connected
    onAttachedChanged: if (attached) attach()

    QuickshellNotificationServer {
        id: server
        enabled: root.serverEnabled
        quiet: root.dnd
        onArrived: item => { if (root.attached) root.ingest(item); }
        onChanged: item => { if (root.attached) root.ingest(item); }
        onClosed: key => { if (root.attached) root.core.request("notif.closed", { id: key }); }
    }
}
