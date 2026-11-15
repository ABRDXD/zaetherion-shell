import QtQuick
import Quickshell
import Quickshell.Io
import qs.view.contract

// DMS's launcher engine through the bridge inside DMS (adapters/dms/bridge, Z197): one JSON object per line on a
// private socket in the runtime folder. Connected means available; it tries again every few seconds while DMS is
// away (a restart, or a copy made before the bridge), and the star chart falls back to the core's ranking meanwhile.
LauncherDomain {
    id: root
    readonly property string path: Quickshell.env("ZAETHERION_LAUNCHER_SOCKET")
        || (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/zaetherion/dms-launcher.sock"
    readonly property int retryMs: 3000
    available: socket.connected

    // DMS's item types as the star chart's kinds ("clip" for a clipboard entry); anything new reads as a plugin.
    readonly property var kinds: ({ app: "app", file: "file", setting: "setting", plugin: "plugin", clipboard: "clip" })
    function icon(item) {
        if (item.iconType !== "image" || !item.icon) return "";
        if (item.icon.startsWith("/") || item.icon.includes("://")) return item.icon;
        return Quickshell.iconPath(item.icon, true);
    }
    function row(item) {
        return { key: item.key, id: item.id ?? "", kind: kinds[item.type] ?? "plugin", name: item.name, description: item.subtitle,
                 icon: icon(item), glyph: item.iconType === "material" ? item.icon : "", source: item.source };
    }
    function send(message) {
        if (!socket.connected) return;
        socket.write(JSON.stringify(message) + "\n");
        socket.flush();
    }
    function receive(line) {
        let message;
        try { message = JSON.parse(line); } catch (error) { return; }
        if (message.event !== "results") return;
        query = String(message.query ?? "");
        searching = message.searching === true;
        results = (message.items ?? []).map(row);
    }
    function open() { record("open", []); send({ op: "open" }); }
    function search(text: string) { record("search", [text]); send({ op: "query", text: text }); }
    function execute(key: int) { record("execute", [key]); send({ op: "execute", key: key }); }
    function close() { record("close", []); send({ op: "close" }); }

    Socket {
        id: socket
        path: root.path
        connected: true
        parser: SplitParser { onRead: line => root.receive(line) }
        onConnectedChanged: if (!connected) { root.results = []; root.searching = false; }
    }
    Timer {
        interval: root.retryMs
        repeat: true
        running: !socket.connected
        onTriggered: socket.connected = true
    }
}
