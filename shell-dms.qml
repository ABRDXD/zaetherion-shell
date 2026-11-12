//@ pragma UseQApplication
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic
//@ pragma Env QS_NO_RELOAD_POPUP=1
// The ZÆTHERION session's entry (S2): shell.qml with DmsAdapter in place of SerpantinumAdapter. The DMS socket is
// DMS_SOCKET (docs/DMS_ADAPTER.md §7). Nothing starts this file yet; the switch-over belongs to the session config.
import QtQuick
import Quickshell
import Quickshell.Io
import qs.adapters.dms
import qs.core.client
import qs.view.overdrive
import qs.view.shell
import qs.view.ui
ShellRoot {
    id: root
    CoreClient { id: client; host: adapter }
    DmsAdapter {
        id: adapter
        core: client
        role: "shell"
        // With a core, DMS's socket follows the supervisor (it changes with every DMS restart, and is null while
        // DMS is down); without one, DMS_SOCKET.
        socketPath: client.connected ? (client.supervisorData?.children?.dms?.socket ?? "") : (Quickshell.env("DMS_SOCKET") ?? "")
    }

    // The island (S3) runs only where the session asks for it, so without ZAETHERION_ISLAND=1 this shell is the panel alone.
    readonly property bool islandWanted: Quickshell.env("ZAETHERION_ISLAND") === "1"
    // The owner's choices (Z155) come from the core's `island` topic (the `island` verb sets them); the
    // environment only stands in while no core is connected.
    readonly property var islandSettings: client.islandData ?? ({
        form: Quickshell.env("ZAETHERION_ISLAND_FORM") === "fluid" ? "fluid" : "angular",
        edge: Quickshell.env("ZAETHERION_ISLAND_EDGE") === "bottom" ? "bottom" : "top",
        placement: Quickshell.env("ZAETHERION_ISLAND_PLACEMENT") === "floating" ? "floating" : "notch",
        screen: Quickshell.env("ZAETHERION_ISLAND_OUTPUT") ?? ""
    })
    readonly property string islandOutput: islandSettings.screen ?? ""
    Binding { target: Design; property: "form"; value: root.islandSettings.form === "fluid" ? "fluid" : "angular" }
    readonly property var islandScreen: !islandWanted ? null
        : Quickshell.screens.find(screen => screen.name === islandOutput)
          ?? Quickshell.screens.find(screen => screen.name === adapter.workspaces.focusedScreen)
          ?? Quickshell.screens[0] ?? null
    readonly property var island: islandLoader.item

    Overlay {
        id: panel
        host: adapter
        core: client
        companionWindows: root.island?.companionWindow ? [root.island.companionWindow] : []
        adjacentIslandGap: root.island ? root.island.edgeGap : -1
        islandRect: root.island?.islandRect ?? null
        islandHasKeyboard: root.island?.companionWindow?.wantsKeyboard ?? false
    }
    function showPanel(room: string): void {
        panel.openPage(room, { screen: root.islandScreen?.name ?? "", from: root.island?.islandRect ?? null });
    }
    function togglePanel(room: string): void {
        if (panel.opened) Host.close();
        else showPanel(room);
    }

    OverdriveLease { id: lease; core: client }

    LazyLoader {
        id: islandLoader
        active: root.islandWanted && root.islandScreen !== null
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
            onTogglePanel: room => root.togglePanel(room)
            // A long press ignites, or cuts a running Overdrive, as the panel's plate does. FART is folded here, so
            // the Overdrive asked for outlasts it ("sticky") instead of the panel's own "panel" mode.
            onIgnite: lease.requested ? lease.release() : lease.request("sticky")
            // Notification actions and replies need S4's notification server; the contract has no call for them yet.
            onNotificationAction: (id, action, reply) => console.warn("island: notification actions wait for S4")
        }
    }
    // Super+Shift+I (Z148): `qs -p <repo>/shell.qml ipc call island focus`. With FART open the island takes the
    // keyboard and FART stays open; Esc hands it back.
    IpcHandler {
        target: "island"
        function focus(): void { root.island?.focusIsland(); }
    }
}
