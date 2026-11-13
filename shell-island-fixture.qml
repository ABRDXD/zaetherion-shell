//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env FART_STATE_DIR=/dev/null/zaetherion-island-fixture
//@ pragma Env FART_CACHE_DIR=/dev/null/zaetherion-island-fixture
import QtQuick
import Quickshell
import Quickshell.Io
import qs.adapters.fixture
import qs.core.client
import qs.view.cues
import qs.view.shell
import qs.view.ui

// Standalone island preview. Run against an isolated compositor.
ShellRoot {
    id: root
    readonly property string outputName: Quickshell.env("ZAETHERION_FIXTURE_OUTPUT")
    readonly property string edge: Quickshell.env("ZAETHERION_FIXTURE_EDGE")
    readonly property string placement: Quickshell.env("ZAETHERION_FIXTURE_PLACEMENT")
    readonly property var target: outputName
        ? Quickshell.screens.find(screen => screen.name === outputName) ?? null
        : Quickshell.screens.length === 1 ? Quickshell.screens[0] : null

    FixtureAdapter { id: fixture }
    CoreClient { id: core; path: ""; host: fixture }
    property bool overdrive: false
    property var notice: null
    property int sampleId: 0
    property int waveStep: 0

    Overlay {
        id: panel
        host: fixture
        core: core
        companionWindows: island.companionWindow ? [island.companionWindow] : []
        adjacentIslandGap: island.edgeGap
        islandRect: island.islandRect
        islandHasKeyboard: island.companionWindow?.wantsKeyboard ?? false
        islandAlert: island?.coveredEvent ?? null
        onIslandAlertDismissed: id => island?.dismissCovered(id)
        onIslandAlertAction: (id, action, reply) => fixture.notifications.record("action", [id, action, reply])
    }
    function showPanel(room: string): void {
        panel.openPage(room, { screen: target?.name ?? "", from: island.islandRect });
    }
    function togglePanel(room: string): void {
        if (panel.opened) Host.close();
        else showPanel(room);
    }

    Timer {
        interval: 50  // 20 Hz, as tools/cava.conf (docs/ISLAND_DIAGNOSIS.md)
        running: fixture.media.holds("spectrum")
        repeat: true
        onTriggered: {
            root.waveStep += 1;
            fixture.media.spectrum = Array.from({ length: 24 }, (_, i) =>
                Math.abs(Math.sin(i * 0.45 + root.waveStep * 0.19)) * (1 - i / 28));
        }
        onRunningChanged: if (!running) fixture.media.spectrum = [];
    }
    Component.onCompleted: {
        // The approved mock-up uses the Design fallback palette.
        fixture.palette.colors = ({});
        Design.source = fixture.palette;
        Design.form = Quickshell.env("ZAETHERION_FIXTURE_FORM") === "fluid" ? "fluid" : "angular";
    }
    Component.onDestruction: Design.source = null

    Binding { target: Motion; property: "profile"; value: fixture.motion.roles }

    IslandWindow {
        id: island
        host: fixture
        core: core
        startupNotice: root.notice
        systemVoice: Quickshell.env("ZAETHERION_FIXTURE_VOICE") !== "plain"
        workspaceIds: ["1", "2", "3", "4", "5", "6", "7"]
        overdriveActive: root.overdrive
        keyboardPeer: panel.holdsKeyboard
        onOpenPanel: room => root.showPanel(room)
        onTogglePanel: room => root.togglePanel(room)
        docked: panel.retained
        onIgnite: root.overdrive = true
        onNotificationAction: (id, action, reply) => fixture.notifications.record("action", [id, action, reply])
        output: target
        bottomEdge: edge === "bottom"
        edgeGap: placement === "floating" ? 16 : 0
    }

    IpcHandler {
        target: "island-fixture"
        function state(): string {
            const calls = fixture.notifications.calls.filter(call => call.method === "action");
            const args = calls[calls.length - 1]?.args ?? [];
            return JSON.stringify({ panelOpen: panel.opened, panelRetained: panel.retained,
                island: island.islandRect, overdrive: root.overdrive, notificationActions: calls.length,
                draftLength: island.companionWindow?.draftLength ?? 0,
                lastNotificationAction: args[1] ?? "", lastReplyLength: args[2]?.length ?? 0,
                lastReply: args[2] ?? "", keyboard: island.companionWindow?.keyboardRequest ?? "",
                powerCalls: fixture.power.calls.map(call => call.method),
                coveredEvent: island.coveredEvent?.kind ?? "" });
        }
        function focus(): void { island.focusIsland(); }
        function tray(): void { island.openTray("sample"); }
        function power(): void { island.openSession(); }
        function panel(room: string): void { root.togglePanel(room); }
        function recording(on: bool): void {
            fixture.capture.recording = { active: on, startedAt: Date.now() / 1000 };
        }
        function battery(level: real, charging: bool): void {
            fixture.power.battery = { available: true, level: Math.max(0, Math.min(1, level)), charging,
                pluggedIn: charging };
        }
        function comeback(seconds: int): void {
            root.notice = { kind: "backend", label: "> BACKEND · BACK · DOWN " + seconds + " s" };
        }
        function playing(on: bool): void {
            fixture.media.active = Object.assign({}, fixture.media.active, { playing: on });
        }
        function track(): void {
            fixture.media.active = Object.assign({}, fixture.media.active,
                { title: ++root.sampleId % 2 ? "Fixture Horizon" : "Fixture Signal" });
        }
        function form(name: string): void { Design.form = name === "fluid" ? "fluid" : "angular"; }
        function icons(style: string): void { Design.fluidIcons = style; }
        function nomedia(): void { fixture.media.active = null; }
        function trayItems(count: int): void {
            fixture.tray.items = Array.from({ length: Math.max(0, count) }, (_, i) =>
                ({ id: "sample-" + i, title: "Sample tray item " + (i + 1), icon: "", status: "active", hasMenu: i === 0 }));
        }
        function title(text: string): void {
            fixture.media.active = Object.assign({}, fixture.media.active, { title: text });
        }
        function volume(level: real): void {
            fixture.osd.event = { kind: "volume", level: Math.max(0, Math.min(1, level)), muted: false };
        }
        function notification(critical: bool): void {
            const id = "sample-" + (++root.sampleId);
            fixture.notifications.items = fixture.notifications.items.concat([
                { id, appName: "DEMO APP", summary: "Fixture notification",
                  body: "Synthetic notice for the island preview.", urgency: critical ? "critical" : "normal",
                  actions: [{ id: "view", label: "View" }], reply: "reply" }
            ]);
            fixture.notifications.unread += 1;
        }
        // An S4 item as our own server gives it: a picture, two actions, and its own showing time (0 = stays).
        function pictureNotification(timeoutMs: int): void {
            const id = "sample-" + (++root.sampleId);
            fixture.notifications.items = fixture.notifications.items.concat([
                { id, appName: "DEMO APP", summary: "Fixture picture", body: "Synthetic notice with a picture.",
                  urgency: "normal", time: Date.now(), live: true, timeout: timeoutMs,
                  image: Qt.resolvedUrl("docs/ui/island-s3-layout-review.png"),
                  actions: [{ id: "view", label: "View" }, { id: "later", label: "Later" }], reply: "" }
            ]);
            fixture.notifications.unread += 1;
        }
        function closeNotifications(): void { fixture.notifications.items = []; }
        function memory(stallPercent: real): void {
            fixture.system.memory = Object.assign({}, fixture.system.memory,
                { pressureSomeAvg10: stallPercent, processes: [
                    { name: "Sample process A", pss: 2097152 }, { name: "Sample process B", pss: 1048576 },
                    { name: "Sample process C", pss: 524288 }
                ] });
        }
        function workspace(id: string): void { fixture.workspaces.activeId = id; }
        function fullscreen(on: bool): void {
            const monitor = root.target?.name;
            if (!monitor) return;
            fixture.workspaces.workspaces = [{ id: "1", monitor, active: true }];
            fixture.workspaces.windows = [{ workspaceId: "1", monitor, fullscreen: on }];
        }
    }
}
