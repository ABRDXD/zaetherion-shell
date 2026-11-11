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
    property bool powerPreview: false
    property var notice: null
    property int sampleId: 0
    property int waveStep: 0

    Overlay {
        id: panel
        host: fixture
        core: core
        companionWindows: island.companionWindow ? [island.companionWindow] : []
        adjacentIslandGap: island.edgeGap
    }
    function showPanel(room: string): void {
        panel.openPage(room, { screen: target?.name ?? "", from: island.islandRect });
    }
    function togglePanel(room: string): void {
        if (panel.opened) Host.close();
        else showPanel(room);
    }

    LazyLoader {
        active: root.powerPreview
        FloatingWindow {
            title: "Session card · fixture"
            screen: root.target
            implicitWidth: 256
            implicitHeight: 252
            color: Design.islandFill
            onVisibleChanged: if (!visible) root.powerPreview = false
            Column {
                anchors.fill: parent
                anchors.margins: 12
                spacing: Design.baseline
                FText { text: "> SESSION CARD · FIXTURE"; color: Design.accent; technical: true }
                Repeater {
                    model: ["Lock", "Suspend", "Log out", "Reboot", "Power off"]
                    FText {
                        required property string modelData
                        text: modelData
                        color: Design.muted
                        height: Design.minHit
                    }
                }
                FButton {
                    label: "Close"
                    height: Design.minHit
                    onClicked: root.powerPreview = false
                }
            }
        }
    }

    Timer {
        interval: 33
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
        onOpenPanel: room => root.showPanel(room)
        onTogglePanel: room => root.togglePanel(room)
        // Allow for both 84° shoulders so the inside edge meets the body.
        dockedWidth: panel.retained && root.target ? Math.min(1360, root.target.width - 24) + 8 : 0
        onOpenPower: root.powerPreview = !root.powerPreview
        onIgnite: root.overdrive = true
        onNotificationAction: (id, action, reply) => fixture.notifications.record("action", [id, action, reply])
        output: target
        bottomEdge: edge === "bottom"
        edgeGap: placement === "floating" ? 16 : 0
    }

    IpcHandler {
        target: "island-fixture"
        function state(): string {
            const calls = fixture.notifications.calls;
            const args = calls[calls.length - 1]?.args ?? [];
            return JSON.stringify({ panelOpen: panel.opened, panelRetained: panel.retained,
                island: island.islandRect, overdrive: root.overdrive, notificationActions: calls.length,
                draftLength: island.companionWindow?.draftLength ?? 0,
                lastNotificationAction: args[1] ?? "", lastReplyLength: args[2]?.length ?? 0 });
        }
        function focus(): void { island.focusIsland(); }
        function tray(): void { island.openTray("sample"); }
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
