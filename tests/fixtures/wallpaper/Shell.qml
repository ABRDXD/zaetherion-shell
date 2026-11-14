import QtQuick
import Quickshell
import Quickshell.Io
import qs.adapters.fixture
import qs.core.client
import qs.view.cues
import qs.view.shell
import qs.view.ui

// Inert nested fixture for the wallpaper section (Z177). The listing is a JSON file made by core/wallpaper.py's
// scan; images are only read. Nothing is set: choose updates this fake core's topic and the fixture's call log.
ShellRoot {
    id: root
    property var listing: ({ folder: "", exists: true, entries: [] })
    readonly property var target: Quickshell.screens.find(screen => screen.name === "ZTEST") ?? null
    FileView {
        path: Quickshell.env("WALLPAPER_FIXTURE_LISTING")
        onLoaded: {
            root.listing = JSON.parse(text());
            client.wallpaperData = { folder: root.listing.folder, exists: root.listing.exists, recent: [], preview: null,
                available: true, current: Quickshell.env("WALLPAPER_FIXTURE_CURRENT") || "", perScreen: false, error: "" };
        }
    }
    FixtureAdapter { id: fixture }
    CoreClient {
        id: client
        path: ""
        host: fixture
        connected: true
        paletteData: null
        function update(changes) { wallpaperData = Object.assign({}, wallpaperData, changes); }
        function request(op, args, callback) {
            let result = wallpaperData;
            if (op === "wallpaper.list") result = root.listing;
            else if (op === "wallpaper.preview") update({ preview: args.name });
            else if (op === "wallpaper.cancel") update({ preview: null });
            else if (op === "wallpaper.choose") {
                if (!wallpaperData.available) { if (callback) callback(false, { message: wallpaperData.error }); return; }
                fixture.wallpaper.set(args.name);
                update({ current: args.name, preview: null });
            } else if (op === "wallpaper.folder") {
                root.listing = { folder: args.folder, exists: false, entries: [] };
                update({ folder: args.folder, exists: false });
            } else if (op === "palette.list") result = [];
            else if (op.startsWith("palette.")) result = {};
            else { if (callback) callback(false, { message: "Not used by this fixture" }); return; }
            if (callback) callback(true, result);
        }
    }
    Binding { target: Motion; property: "profile"; value: fixture.motion.roles }
    Component.onCompleted: {
        Design.form = "fluid";
        fixture.network.available = false;
        fixture.system.user = "";
        fixture.system.hostname = "";
        fixture.media.active = null;
        fixture.notifications.items = [];
    }
    Overlay {
        id: panel
        host: fixture
        core: client
        companionWindows: island.companionWindow ? [island.companionWindow] : []
        adjacentIslandGap: island.edgeGap
        islandRect: island.islandRect
        islandHasKeyboard: island.companionWindow?.wantsKeyboard ?? false
    }
    IslandWindow {
        id: island
        host: fixture
        core: client
        output: root.target
        workspaceIds: ["1", "2", "3"]
        docked: panel.retained
        keyboardPeer: panel.holdsKeyboard
        onOpenPanel: room => panel.openPage(room, {screen: root.target.name, from: island.islandRect})
        onTogglePanel: room => panel.openPage(room, {screen: root.target.name, from: island.islandRect})
    }
    IpcHandler {
        target: "wallpaper-fixture"
        function open(section: string): void {
            panel.openPage("home", {screen: root.target.name, from: island.islandRect});
            Host.openSettings(section);
        }
        function close(): void { Host.close(); }
        function preview(index: int): void { client.update({ preview: root.listing.entries[index]?.path ?? null }); }
        function host(available: bool, error: string): void { client.update({ available: available, error: error }); }
        function empty(folder: string): void {
            root.listing = { folder: folder, exists: false, entries: [] };
            client.update({ folder: folder, exists: false });
        }
        function state(): string {
            return JSON.stringify({ open: panel.opened, wallpaper: client.wallpaperData, calls: fixture.wallpaper.calls });
        }
    }
}
