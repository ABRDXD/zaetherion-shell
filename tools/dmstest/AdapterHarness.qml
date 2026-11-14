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
    property var prompts: []
    property var pairings: []
    Connections {
        target: adapter.network
        function onPromptArrived(id) { root.prompts = root.prompts.concat([id]); }
    }
    Connections {
        target: adapter.bluetooth
        function onPairingArrived(id) { root.pairings = root.pairings.concat([id]); }
    }
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
                powerAvailable: adapter.power.available, notificationsAvailable: adapter.notifications.available, trayAvailable: adapter.tray.available, trayItems: adapter.tray.items.length,
                workspacesAvailable: adapter.workspaces.available, mediaAvailable: adapter.media.available
            });
        }
        // Hyprland, only ever run inside the hidden nested compositor (tools/nested_hypr.py).
        function hypr(): string {
            const w = adapter.workspaces;
            return JSON.stringify({ focusedScreen: w.focusedScreen, activeId: w.activeId,
                workspaces: w.workspaces.map(s => s.id), monitors: w.monitors.map(m => m.name), binds: adapter.keybinds.binds.length });
        }
        // The session card's calls. Tests run them only with stub commands on PATH.
        function session(action: string): void {
            const p = adapter.power;
            if (action === "lock") p.lock();
            else if (action === "suspend") p.suspend();
            else if (action === "logout") p.logout();
            else if (action === "reboot") p.reboot();
            else if (action === "powerOff") p.powerOff();
        }
        function switchTo(id: string): void { adapter.workspaces.switchTo(id); }
        function refreshBinds(): void { adapter.keybinds.refresh(); }
        // S10 (docs/NET_BT.md): Wi-Fi, VPN and Bluetooth through the contract. Secrets here are fake test values.
        function net(): string {
            const n = adapter.network;
            return JSON.stringify({ available: n.available, connecting: n.connecting, wired: n.wired, vpns: n.vpns,
                preference: n.preference, attempt: n.attempt, vpnAttempt: n.vpnAttempt, prompt: n.prompt, saved: n.saved,
                prompts: root.prompts, pairings: root.pairings });
        }
        function timeouts(ms: string): void {
            const t = Number(ms);
            adapter.network.wifiTimeout = t; adapter.network.vpnTimeout = t; adapter.network.promptTimeout = t;
            adapter.bluetooth.connectTimeout = t; adapter.bluetooth.pairTimeout = t; adapter.bluetooth.otherTimeout = t;
            adapter.bluetooth.pairingTimeout = t;
        }
        function join(ssid: string, secret: string, hidden: string): void { adapter.network.join(ssid, secret, hidden === "true"); }
        function forget(id: string): void { adapter.network.forget(id); }
        function autoconnect(id: string, on: string): void { adapter.network.setAutoconnect(id, on === "true"); }
        function preference(value: string): void { adapter.network.setPreference(value); }
        function vpn(id: string, on: string): void { adapter.network.setVpn(id, on === "true"); }
        function disconnectWifi(): void { adapter.network.disconnect(); }
        function answer(id: string, secret: string): void { adapter.network.answerPrompt(id, secret); }
        function cancelPrompt(id: string): void { adapter.network.cancelPrompt(id); }
        function dismiss(): void { adapter.network.dismissAttempt(); }
        function bt(): string {
            const b = adapter.bluetooth;
            return JSON.stringify({ available: b.available, enabled: b.enabled, discovering: b.discovering, devices: b.devices,
                nearby: b.nearby, primary: b.primary, attempts: b.attempts, pairing: b.pairing });
        }
        function btPower(on: string): void { adapter.bluetooth.setEnabled(on === "true"); }
        function btDo(action: string, id: string): void {
            const b = adapter.bluetooth;
            if (action === "connect") b.connect(id);
            else if (action === "disconnect") b.disconnect(id);
            else if (action === "pair") b.pair(id);
            else if (action === "forget") b.forget(id);
            else if (action === "trust") b.trust(id, true);
            else if (action === "untrust") b.trust(id, false);
        }
        function btAnswer(id: string, code: string): void { adapter.bluetooth.answerPairing(id, code); }
        function btCancel(id: string): void { adapter.bluetooth.cancelPairing(id); }
        function btAcquire(feature: string): void { adapter.bluetooth.acquire(feature, "t"); }
        function btRelease(feature: string): void { adapter.bluetooth.release(feature, "t"); }
        function results(): string { return JSON.stringify(root.results); }
        function quit(): void { Qt.quit(); }
    }
}
