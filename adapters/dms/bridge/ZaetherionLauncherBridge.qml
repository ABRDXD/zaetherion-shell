import QtQuick
import Quickshell
import Quickshell.Io
import qs.Modals.DLauncherV2

// Runs inside DMS, not in ZÆTHERION (Z197). tools/dms_quiet.py copies this file into the quiet DMS copy beside DMS's
// launcher and adds one instance to DMSShell.qml. It drives DMS's own launcher engine (`Controller`: apps with its
// frecency and actions, files through dsearch, clipboard, DMS settings, plugins) without DMS's window, and serves it to
// ZÆTHERION's star chart over a private socket in the runtime folder, one JSON object per line.
//
//   → {"op": "open"}                 the engine starts (DMS loads its lists)
//   → {"op": "query", "text": "fi"}  a new search; results arrive as events, as DMS's phases complete
//   → {"op": "execute", "key": 3}    run result 3 of the latest results, as DMS's own Enter would
//   → {"op": "close"}                the engine stops (DMS records history and clears)
//   ← {"event": "results", "query", "searching", "items": [{key, type, name, subtitle, icon, iconType, section,
//      source, pluginId}]}
//   ← {"event": "executed", "key"}
//
// Only plain values cross the socket; DMS's item objects stay here, looked up again by key.
Item {
    id: root
    visible: false
    // ZAETHERION_LAUNCHER_SOCKET moves it (tests); the default is where ZÆTHERION's adapter looks.
    readonly property string path: Quickshell.env("ZAETHERION_LAUNCHER_SOCKET")
        || (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/zaetherion/dms-launcher.sock"
    readonly property int maxItems: 50
    property var client: null
    property var shown: []   // DMS's items behind the keys last sent

    Controller {
        id: engine
        active: false
        viewModeContext: "spotlight"
        forceLinearNavigation: true
        onSearchCompleted: root.push()
        onIsSearchingChanged: root.push()
        onSearchQueryRequested: query => engine.setSearchQuery(query)
        onItemExecuted: root.send({ event: "executed" })
    }

    function plain(item, key) {
        return { key: key, id: String(item.id ?? ""), type: item.type ?? "", name: String(item.name ?? ""), subtitle: String(item.subtitle ?? ""),
                 icon: String(item.icon ?? ""), iconType: String(item.iconType ?? ""), section: String(item.section ?? ""),
                 source: String(item.source ?? ""), pluginId: String(item.pluginId ?? "") };
    }
    function push() {
        if (!client) return;
        const items = [];
        for (const row of engine.flatModel || []) {
            if (row.isHeader || !row.item) continue;
            items.push(row.item);
            if (items.length >= maxItems) break;
        }
        shown = items;
        send({ event: "results", query: engine.searchQuery, searching: engine.isSearching, items: items.map(plain) });
    }
    function send(message) {
        if (!client) return;
        client.write(JSON.stringify(message) + "\n");
        client.flush();
    }
    function handle(socket, line) {
        let message;
        try { message = JSON.parse(line); } catch (error) { return; }
        client = socket;
        switch (message.op) {
        case "open":
            engine.active = true;
            push();
            break;
        case "query":
            if (!engine.active) engine.active = true;
            engine.setSearchQuery(String(message.text ?? ""));
            break;
        case "execute": {
            const item = shown[message.key];
            if (item) engine.executeItem(item, true, false);
            break;
        }
        case "close":
            engine.active = false;
            break;
        }
    }

    SocketServer {
        active: true
        path: root.path
        handler: Socket {
            id: socket
            parser: SplitParser { onRead: line => root.handle(socket, line) }
            onConnectedChanged: {
                if (!connected && root.client === socket) {
                    root.client = null;
                    engine.active = false;
                }
            }
        }
    }
}
