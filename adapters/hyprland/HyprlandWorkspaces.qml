// Derived from adapters/serpantinum/SerpantinumWorkspaces.qml (this repository; it uses only Quickshell primitives). See NOTICE.
import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.view.contract

WorkspacesDomain {
    id: root
    readonly property var monitorNames: {
        const result = {};
        for (const m of Hyprland.monitors.values) result[m.id] = m.name;
        return result;
    }
    available: true
    focusedScreen: Hyprland.focusedMonitor?.name ?? ""
    activeId: Hyprland.focusedMonitor?.activeWorkspace ? String(Hyprland.focusedMonitor.activeWorkspace.id) : ""
    workspaces: Hyprland.workspaces.values.filter(w => w.id > 0).map(w => ({ id: String(w.id), name: w.name, monitor: w.monitor?.name ?? "",
        active: w.active, windowCount: w.toplevels.values.length }))
    windows: Hyprland.toplevels.values.map(t => {
        const ipc = t.lastIpcObject ?? {};
        // appId: the Wayland toplevel always carries it; Hyprland's IPC cache (lastIpcObject) may still be empty.
        return { id: t.address, title: t.title, appId: t.wayland?.appId || ipc.class || "", workspaceId: t.workspace ? String(t.workspace.id) : "",
            monitor: t.monitor?.name ?? monitorNames[ipc.monitor] ?? "",
            x: ipc.at?.[0] ?? 0, y: ipc.at?.[1] ?? 0, width: ipc.size?.[0] ?? 0, height: ipc.size?.[1] ?? 0,
            floating: ipc.floating === true, fullscreen: !!ipc.fullscreen, focused: t === Hyprland.activeToplevel };
    })
    monitors: Hyprland.monitors.values.map(m => ({ name: m.name, x: m.x, y: m.y, width: m.width, height: m.height, scale: m.scale || 1,
        reservedTop: m.lastIpcObject?.reserved?.[1] ?? 0, reservedBottom: m.lastIpcObject?.reserved?.[3] ?? 0 }))

    // Hyprland 0.57's dispatchers are Lua (the session's own binds use hl.dsp.focus). Ids are checked first: they are
    // spliced into the call.
    function switchTo(workspaceId: string) {
        if (/^[A-Za-z0-9_.:-]+$/.test(workspaceId)) Hyprland.dispatch("hl.dsp.focus({ workspace = " + JSON.stringify(workspaceId) + " })");
    }
    function focusWindow(windowId: string) { Hyprland.toplevels.values.find(t => t.address === windowId)?.wayland?.activate(); }
    // Hyprland 0.57's dispatcher is Lua. Quickshell's addresses have no 0x; Hyprland's selector needs it. `follow = false` moves the
    // window and leaves you where you are.
    function moveWindow(windowId: string, workspaceId: string) {
        const address = windowId.startsWith("0x") ? windowId : "0x" + windowId;
        Hyprland.dispatch('hl.dsp.window.move({ workspace = "' + workspaceId + '", follow = false, window = "address:' + address + '" })');
    }
    function thumbnailSource(windowId: string) { return Hyprland.toplevels.values.find(t => t.address === windowId)?.wayland ?? null; }
}
