import QtQuick
import Quickshell
import Quickshell.Io
import qs.adapters.fixture
import qs.core.client
import qs.view.cues
import qs.view.shell
import qs.view.ui

// Inert nested fixture. The catalogue is normalized at runtime, never bundled from a host install.
ShellRoot {
    id: root
    property var entries: ({})
    property int noticeId: 0
    readonly property var target: Quickshell.screens.find(screen => screen.name === "ZTEST") ?? null
    FileView {
        path: Quickshell.env("PALETTE_FIXTURE_CATALOG")
        onLoaded: {
            root.entries = JSON.parse(text());
            client.choose("dms:amoledBlack");
        }
    }
    FixtureAdapter { id: fixture }
    CoreClient {
        id: client
        path: ""
        host: fixture
        connected: true
        function choose(name) {
            const entry = root.entries[name];
            if (!entry) return;
            paletteData = {name, effective: name, colors: entry.colors, savedColors: entry.colors, preview: false};
        }
        function request(op, args, callback) {
            if (op === "palette.list") {
                callback(true, Object.values(root.entries).map(entry => ({id: entry.id, name: entry.name,
                    source: entry.source, study: entry.study, accent: entry.colors.accent})));
                return;
            }
            if (op === "palette.choose") choose(args.name);
            else if (op === "palette.preview") paletteData = Object.assign({}, paletteData,
                {effective: args.name, colors: root.entries[args.name].colors, preview: true});
            else if (op === "palette.cancel" && paletteData) paletteData = Object.assign({}, paletteData,
                {effective: paletteData.name, colors: paletteData.savedColors, preview: false});
            else { if (callback) callback(false, {message: "Not used by this fixture"}); return; }
            if (callback) callback(true, paletteData);
        }
    }
    Binding { target: Motion; property: "profile"; value: fixture.motion.roles }
    Component.onCompleted: {
        Design.form = "fluid";
        fixture.network.available = false;
        fixture.network.connected = false;
        fixture.network.name = "";
        fixture.network.networks = [];
        fixture.system.user = "";
        fixture.system.hostname = "";
        fixture.media.active = null;
        fixture.notifications.items = [];
        fixture.notifications.unread = 0;
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
        target: "palette-fixture"
        function select(name: string): void { client.choose(name); }
        function panel(on: bool): void {
            if (on) panel.openPage("home", {screen: root.target.name, from: island.islandRect});
            else Host.close();
        }
        function preferences(): bool { return panel.openPreferences(); }
        function notice(): void {
            fixture.notifications.items = [{id: "palette-study-" + (++root.noticeId), appName: "PALETTE STUDY",
                summary: "A quiet signal", body: "Colour carries the accent. The surface stays black.",
                urgency: "normal", actions: []}];
            fixture.notifications.unread = 1;
        }
        function state(): string {
            return JSON.stringify({palette: client.paletteData?.name, colors: Design.palette, open: panel.opened});
        }
    }
}
