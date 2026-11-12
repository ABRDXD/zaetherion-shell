import QtQuick
import Quickshell
import Quickshell.Io
import qs.adapters.dms
import qs.core.client

// Driven by tests/test_dms_adapter.py over `qs ipc`. Offscreen, against the stand-in DMS (tools/dms_replay.py).
// It never contacts a real DMS: the socket path comes from the test's private DMS_SOCKET.
ShellRoot {
    id: root
    CoreClient { id: client }
    DmsAdapter { id: adapter; core: client; role: "test" }

    property var results: []
    property var extraFeed: null
    property var unknown: []
    Connections {
        target: adapter.network
        function onUnknownNetwork(id) { root.unknown = root.unknown.concat([id]); }
    }
    Component {
        id: feedFactory
        DmsFeed { link: adapter.dms; service: "brightness"; capability: "brightness"; wanted: true }
    }

    IpcHandler {
        target: "t"
        function state(): string {
            const n = adapter.network, l = adapter.dms;
            return JSON.stringify({
                phase: l.phase, problem: l.problem, apiVersion: l.apiVersion, cliVersion: l.cliVersion, untested: l.untested,
                capabilities: l.capabilities, events: l.eventsState, subscribed: l.subscribed,
                available: n.available, wifiEnabled: n.wifiEnabled, kind: n.kind, connected: n.connected, name: n.name,
                ipAddress: n.ipAddress, networks: n.networks, unknown: root.unknown, name2: adapter.name,
                extra: root.extraFeed ? { usable: root.extraFeed.usable, hasData: root.extraFeed.data !== null } : null
            });
        }
        function acquire(feature: string): void { adapter.network.acquire(feature, "t"); }
        function release(feature: string): void { adapter.network.release(feature, "t"); }
        function wifi(on: string): void { adapter.network.setWifiEnabled(on === "true"); }
        function connect(id: string): void { adapter.network.connect(id); }
        function setPath(path: string): void { adapter.socketPath = path; }
        function extra(on: string): void {
            if (on === "true" && !root.extraFeed) root.extraFeed = feedFactory.createObject(root);
            else if (on !== "true" && root.extraFeed) { root.extraFeed.destroy(); root.extraFeed = null; }
        }
        // A request through the link itself, answered into results().
        function call(method: string): void {
            adapter.dms.call(method, undefined, (result, error) => {
                root.results = root.results.concat([{ method: method, result: result, error: error }]);
            }, 1500);
        }
        // The rest of the adapter: which implementation fills each domain, after loadDeferred().
        function domains(): string {
            const kind = d => String(d).replace(/_QMLTYPE.*|\(0x.*$/, "");
            adapter.loadDeferred();
            return JSON.stringify({
                media: kind(adapter.media), audio: kind(adapter.audio), network: kind(adapter.network), notifications: kind(adapter.notifications),
                workspaces: kind(adapter.workspaces), power: kind(adapter.power), tray: kind(adapter.tray), keybinds: kind(adapter.keybinds),
                lyrics: kind(adapter.lyrics), clipboard: kind(adapter.clipboard), system: kind(adapter.system),
                powerAvailable: adapter.power.available, trayAvailable: adapter.tray.available, trayItems: adapter.tray.items.length,
                workspacesAvailable: adapter.workspaces.available, mediaAvailable: adapter.media.available
            });
        }
        // Hyprland, only ever run inside the hidden nested compositor (tools/nested_hypr.py).
        function hypr(): string {
            const w = adapter.workspaces;
            return JSON.stringify({ focusedScreen: w.focusedScreen, activeId: w.activeId,
                workspaces: w.workspaces.map(s => s.id), monitors: w.monitors.map(m => m.name), binds: adapter.keybinds.binds.length });
        }
        function switchTo(id: string): void { adapter.workspaces.switchTo(id); }
        function refreshBinds(): void { adapter.keybinds.refresh(); }
        function results(): string { return JSON.stringify(root.results); }
        function quit(): void { Qt.quit(); }
    }
}
