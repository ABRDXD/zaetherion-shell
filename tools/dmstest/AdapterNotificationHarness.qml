import QtQuick
import Quickshell
import Quickshell.Io
import qs.adapters.dms
import qs.core.client

// Driven by tests/test_notification_server.py over `qs ipc`, like NotificationHarness.qml, but through the whole
// DmsAdapter, and the panel is never opened (loadDeferred is never called): with FART_NOTIFICATION_SERVER=1 our
// server must still hold the name from the start. No DMS socket is given, so the adapter never dials one.
ShellRoot {
    CoreClient { id: client }
    DmsAdapter { id: adapter; core: client; role: "test"; socketPath: "" }

    IpcHandler {
        target: "t"
        function state(): string {
            const n = adapter.notifications;
            return JSON.stringify({
                connected: client.connected, deferred: adapter.deferredRequested,
                available: n.available, source: n.source ?? "", items: n.items ?? []
            });
        }
    }
}
