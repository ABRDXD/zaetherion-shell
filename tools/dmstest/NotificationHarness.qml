import QtQuick
import Quickshell
import Quickshell.Io
import qs.adapters.dms
import qs.core.client

// Driven by tests/test_notification_server.py over `qs ipc`. Offscreen, on the test's private session bus and
// against its private core: our notification server (FART_NOTIFICATION_SERVER=1) and the Inbox it reports to.
ShellRoot {
    CoreClient { id: client }
    DmsNotifications { id: notifications; core: client }

    IpcHandler {
        target: "t"
        function state(): string {
            return JSON.stringify({
                connected: client.connected, available: notifications.available, source: notifications.source,
                dnd: notifications.dnd, unread: notifications.unread, items: notifications.items
            });
        }
        function dismiss(id: string): void { notifications.dismiss(id); }
        function invoke(id: string, action: string, reply: string): void { notifications.invoke(id, action, reply); }
        function dnd(on: string): void { notifications.setDnd(on === "true"); }
        function markAllRead(): void { notifications.markAllRead(); }
    }
}
