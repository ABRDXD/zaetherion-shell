//@ pragma UseQApplication
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic
//@ pragma Env QS_NO_RELOAD_POPUP=1
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.adapters.serpantinum
import qs.adapters.hyprland
import qs.core.client
import qs.view.overdrive
import qs.view.shell
import qs.view.ui
import qs.view.widgets
ShellRoot {
    id: root
    // The live view never reloads itself when files change (several agents edit and merge in this checkout; a reload
    // mid-session left the launcher without answers, 15 Nov 2026). Changes load when the core restarts the view.
    settings.watchFiles: false
    CoreClient { id: client; host: adapter }
    SerpantinumAdapter { id: adapter; core: client }

    // The island (S3) runs only where the session asks for it: FART-next under Serpantinum keeps Serpantinum's own
    // bar, so without ZAETHERION_ISLAND=1 this shell is the panel alone, as before.
    readonly property bool islandWanted: Quickshell.env("ZAETHERION_ISLAND") === "1"
    // The owner's choices (Z155) come from the core's `island` topic (the `island` verb sets them); the
    // environment only stands in while no core is connected.
    readonly property var islandSettings: client.islandData ?? ({
        form: Quickshell.env("ZAETHERION_ISLAND_FORM") === "fluid" ? "fluid" : "angular",
        edge: Quickshell.env("ZAETHERION_ISLAND_EDGE") === "bottom" ? "bottom" : "top",
        placement: Quickshell.env("ZAETHERION_ISLAND_PLACEMENT") === "floating" ? "floating" : "notch",
        screen: Quickshell.env("ZAETHERION_ISLAND_OUTPUT") ?? "",
        rest: ({ power: "hover", network: "always", battery: "always", inbox: "dot" })
    })
    readonly property string islandOutput: islandSettings.screen ?? ""
    Binding { target: Design; property: "form"; value: root.islandSettings.form === "fluid" ? "fluid" : "angular" }
    readonly property var islandScreen: !islandWanted ? null
        : Quickshell.screens.find(screen => screen.name === islandOutput)
          ?? Quickshell.screens.find(screen => screen.name === adapter.workspaces.focusedScreen)
          ?? Quickshell.screens[0] ?? null
    readonly property var island: islandLoader.item
    // The island runs: it delivers timer, DONE and track, so Overlay's satellites stand down (Z227).
    readonly property bool islandShown: islandWanted && islandScreen !== null

    Overlay {
        id: panel
        host: adapter
        core: client
        companionWindows: root.island?.companionWindow ? [root.island.companionWindow] : []
        adjacentIslandGap: root.island ? root.island.edgeGap : -1
        islandRect: root.island?.islandRect ?? null
        satellitesWanted: !root.islandShown
        islandHasKeyboard: root.island?.companionWindow?.wantsKeyboard ?? false
        islandAlert: root.island?.coveredEvent ?? null
        islandOsd: root.island?.headerOsd ?? null
        onIslandAlertDismissed: id => root.island?.dismissCovered(id)
        onIslandAlertAction: (id, action, reply) => adapter.notifications.invoke(id, action, reply)
    }
    function showPanel(room: string): void {
        panel.openPage(room, { screen: root.islandScreen?.name ?? "", from: root.island?.islandRect ?? null });
    }
    LauncherRoutes { keybinds: adapter.keybinds; island: root.island; panelOpen: panel.opened }
    function togglePanel(room: string): void {
        if (panel.opened) Host.close();
        else showPanel(room);
    }

    OverdriveLease { id: lease; core: client }

    // The desktop clock on every screen whose workspace is empty (Z46, Z85).
    DesktopWidgets {
        id: desktop
        wanted: root.islandWanted
        workspaces: adapter.workspaces
        core: client
    }

    LazyLoader {
        id: islandLoader
        active: root.islandShown
        IslandWindow {
            host: adapter
            core: client
            output: root.islandScreen
            bottomEdge: root.islandSettings.edge === "bottom"
            edgeGap: root.islandSettings.placement === "floating" ? 16 : 0
            workspaceIds: adapter.workspaces.workspaces
                .filter(space => space.monitor === root.islandScreen?.name)
                .map(space => String(space.id))
            overdriveActive: client.overdriveData?.effective === "active"
            docked: panel.retained
            keyboardPeer: panel.holdsKeyboard
            onOpenPanel: room => root.showPanel(room)
            // A hover word ("joining", "pairing"): FART's settings at that section, over Devices.
            onOpenSettings: section => { root.showPanel("devices"); Host.openSettings(section); }
            onTogglePanel: room => root.togglePanel(room)
            // A long press ignites, or cuts a running Overdrive, as the panel's plate does. FART is folded here, so
            // the Overdrive asked for outlasts it ("sticky") instead of the panel's own "panel" mode.
            onIgnite: lease.requested ? lease.release() : lease.request("sticky")
            onNotificationAction: (id, action, reply) => adapter.notifications.invoke(id, action, reply)
            restItems: root.islandSettings.rest ?? ({})
            clipSettings: client.clipsData ?? ({})
            // Ctrl+O in quick paste: FART's Clips room with the query carried.
            onClipRoom: query => {
                ViewState.clipQuery = query;
                root.showPanel("clipboard");
            }
        }
    }
    // Super+V (S3): Hyprland's global shortcut `zaetherion:clips`, delivered to this process with nothing started.
    // Only the island's process registers it.
    HyprlandClipsShortcut {
        enabled: root.islandWanted
        onPressed: root.island?.toggleClips()
    }
    // Super+Shift+I (Z148): `qs -p <repo>/shell.qml ipc call island focus`. With FART open the island takes the
    // keyboard and FART stays open; Esc hands it back.
    IpcHandler {
        target: "island"
        function focus(): void { root.island?.focusIsland(); }
        // The same as Super+V, for a bind that runs a command instead.
        function clips(): void { root.island?.toggleClips(); }
        // Ctrl+Alt+Del: the session card (Z158, Z208).
        function session(): void { root.island?.toggleSession(); }
    }
}
