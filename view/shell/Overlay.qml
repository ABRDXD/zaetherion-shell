import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.core.client
import qs.view.contract
import qs.view.cues as Cues
import qs.view.overdrive
import qs.view.satellites
import qs.view.strata
import qs.view.ui as Fart

Scope {
    id: root
    required property HostAdapter host
    required property CoreClient core
    property string currentPage: "home"
    property bool opened: false
    // The panel opens like a host popup and folds from wherever it is; a reversal takes the
    // time left (docs/CUES.md §9, §15). No scope: the surface's visibility depends on it.
    Unfold { id: unfold; on: root.opened }
    readonly property bool retained: opened || unfold.value > 0
    Binding { target: Cues.Motion; property: "reduced"; value: !ViewState.motionEnabled }
    // Overdrive follows the core's lease (docs/OVERDRIVE.md §1): only an active lease drives; a suspended one
    // (a guard is on) or a released one is Silent, and the engine winds down to rest.
    Binding { target: Cues.Motion; property: "overdrive"; value: root.core.overdriveData?.effective === "active" }
    Binding { target: Cues.Motion; property: "seen"; value: root.retained }
    Binding { target: Cues.Motion; property: "profile"; value: root.host.motion.available ? root.host.motion.roles : ({}) }
    // Cold-start phase markers for tools/measure/cold_breakdown.py --real (FART_COLD_PROBE=1 only).
    ColdProbe {
        id: coldProbe
        window: body.Window.window
        inputFocused: body.shell?.commandLine.inputFocused ?? false
    }
    // Singletons that cannot take properties get the host once, here.
    Component.onCompleted: {
        Host.adapter = host;
        Fart.Design.source = host.palette;
        coldProbe.mark("created");
    }
    // FART preferences that shape host-side work.
    Binding { target: root.host.media; property: "preferredPlayer"; value: Config.options.bar.media.preferredPlayer }
    Binding { target: root.host.system; property: "sampleInterval"; value: Math.max(500, Config.options.resources.updateInterval) }
    ShellContext { id: context; panelOpen: root.opened; core: root.core }
    onOpenedChanged: { Host.panelOpen = opened; reportState(); }
    // The core reaps a closed view, ends panel leases and decides Super+` folds (Q7) from these reports.
    function reportState() {
        core.notify("view.state", { open: root.opened, page: Host.page, cmdlineIdle: root.opened && (body.shell?.commandLine.idle ?? false) });
    }
    Connections {
        target: body.shell?.commandLine ?? null
        function onIdleChanged() { root.reportState(); }
    }
    Connections {
        target: root.core
        function onConnectedChanged() { if (root.core.connected) root.reportState(); }
        function onCommand(action, page, from, extra) {
            coldProbe.mark("command");
            const placement = { from: from, screen: extra?.screen ?? "" };
            if (action === "open" || action === "page") root.openPage(page || root.currentPage, placement);
            // go <moon>: the orbit opens over the room and keys that moon (docs/ORBIT.md, "type to fly").
            if (action === "open" && extra?.fly !== undefined) body.shell?.flyTo(extra.fly);
            else if (action === "close") Host.close();
            else if (action === "toggle") { if (root.opened) Host.close(); else root.openPage(page || root.currentPage, placement); }
        }
    }
    Connections {
        target: Host
        function onPageChanged() { root.reportState(); }
    }
    Connections {
        target: Fart.Feedback
        function onCue(name) { root.core.notify("sfx.play", { cue: name }); }
    }
    // Opening from fully folded picks the screen and the origin. A new rect while open or folding
    // moves nothing: it is stored for the next unfold (DAILY_DRIVER §3).
    function openPage(page, placement) {
        const screenName = placement?.screen || root.host.workspaces.focusedScreen;
        const from = placement?.from;
        if (from && screenName)
            root.host.clockGeometry.setHookRect(screenName, Math.round(from.x), Math.round(from.y), Math.round(from.width), Math.round(from.height));
        if (!opened && unfold.value === 0) {
            surface.screen = Quickshell.screens.find(s => s.name === screenName) ?? Quickshell.screens.find(s => s.name === root.host.workspaces.focusedScreen) ?? Quickshell.screens[0];
            const rect = from ?? root.host.clockGeometry.rectFor(surface.screen.name);
            body.edge = rect?.edge === "bottom" ? "bottom" : "top";
            body.origin = body.originFrom(rect, (surface.screen.width - surface.width) / 2);
        }
        currentPage = page;
        body.show(page);
        opened = true;
        // Every open focuses the command line (Q3), from the clock, Super+` or the CLI.
        body.armInteractive();
        body.focusCommandLine();
        coldProbe.handled();
    }
    Connections {
        target: Host
        function onOpenRequested(page) { root.openPage(page, null); }
        function onCloseRequested() { root.currentPage = Host.page; root.opened = false; }
    }
    // The desktop tier (T3, OVERDRIVE_IDEAS #52–54). It is a separate surface, so it needs no scene graph to check a shader
    // against: its Stratum is `gpu: false`, and the shader inside it has its own.
    readonly property string shownRoom: body.shell?.currentPage ?? root.currentPage
    readonly property var panelSpot: {
        const mon = root.host.workspaces.monitors.find(m => m.name === surface.screen?.name);
        const top = body.edge === "bottom" ? (surface.screen?.height ?? 0) - surface.height - 8 : (mon?.reservedTop ?? 0) + 8;
        return Qt.rect(Math.round(((surface.screen?.width ?? surface.width) - surface.width) / 2), top, surface.width, surface.height);
    }
    Binding { target: Eigenmode; property: "desktop"; value: Qt.rect(0,0,surface.screen?.width ?? 1920,surface.screen?.height ?? 1080) }
    Binding { target: Eigenmode; property: "origin"; value: ViewState.fullscreen ? Qt.point(0,0) : Qt.point(root.panelSpot.x,root.panelSpot.y) }
    // What a closed panel leaves behind while Overdrive goes on: the room and the time, for a quarter of a minute.
    property string residue: ""
    Timer {
        id: residueTimer
        interval: 15000
        onTriggered: root.residue = ""
    }
    function updateResidue() {
        if (retained) {
            residue = "";
            residueTimer.stop();
        } else if (Cues.Motion.driving) {
            const n = body.shell?.navigationPages.findIndex(p => p.id === root.shownRoom) ?? 0;
            residue = String(Math.max(0, n)).padStart(2, "0") + " · " + root.shownRoom.toUpperCase() + " · " + Qt.formatTime(new Date(), "hh:mm");
            residueTimer.restart();
        }
    }
    Stratum {
        name: "field"
        tier: "desktop"
        gpu: false
        wanted: !ViewState.fullscreen && (root.retained || root.residue !== "")
        sourceComponent: DesktopField {
            screen: surface.screen
            panelRect: root.retained ? root.panelSpot : Qt.rect(0, 0, 0, 0)
            roomTurn: body.shell?.navigationPages.findIndex(p => p.id === root.shownRoom) ?? 0
            meridianX: {
                const shell = body.shell;
                if (!shell || !root.retained)
                    return -1;
                const left = shell.sideOf(root.shownRoom) === "left";
                const cut = shell.width < 920 ? 104 : 150;
                return root.panelSpot.x + 24 + 16 + (left ? cut : shell.width - 48 - 32 - cut);
            }
            residue: root.residue
        }
    }
    Loader {
        active: root.retained && Cues.Motion.overdrive && Cues.Motion.reduced && Eigenmode.still && !ViewState.fullscreen
        sourceComponent: DesktopField { screen:surface.screen; eigenOnly:true }
    }
    // Timer, DONE and track-change satellites beside the clock; hidden while the panel is shown.
    Satellites {
        id: satellites
        core: root.core
        host: root.host
        panelOpen: root.retained
        onOpenRoom: page => root.openPage(page, null)
        surface: Component {
            SatelliteWindow {
                screen: Quickshell.screens.find(s => s.name === root.host.workspaces.focusedScreen) ?? Quickshell.screens[0]
                rect: root.host.clockGeometry.rectFor(screen?.name ?? "")
            }
        }
    }
    // Deferred host domains (docs/ADAPTER_CONTRACT.md §1) load once the first open has settled, so their
    // compile never lands inside the unfold, or at once when a room other than Home is shown.
    readonly property bool settledOpen: opened && unfold.value >= 1
    readonly property string shownPage: body.shell?.loadedPage ?? ""
    onSettledOpenChanged: if (settledOpen) host.loadDeferred()
    onShownPageChanged: {
        if (shownPage !== "")
            coldProbe.mark("room");
        if (shownPage !== "" && shownPage !== "home")
            host.loadDeferred();
    }
    // The surface has drawn since it became visible. The grab needs a mapped surface; waiting for the
    // unfold's first 2% instead (as the archive did) held keyboard focus back by about 60 ms (COLDSTART.md).
    property bool surfaceDrawn: false
    onRetainedChanged: {
        if (!retained)
            surfaceDrawn = false;
        updateResidue();
    }
    Connections {
        target: body.Window.window
        enabled: root.retained && !root.surfaceDrawn
        function onFrameSwapped() { root.surfaceDrawn = true; }
    }
    HyprlandFocusGrab {
        active: root.opened && root.surfaceDrawn && !body.shell?.externalDialogOpen
        windows: [surface]
        onCleared: if (!body.shell?.externalDialogOpen) Host.close()
    }
    // Diagnostics only: open, page, close and toggle arrive from the core.
    IpcHandler {
        target: "fart"
        function status(): string {
            return JSON.stringify({host: root.host.name, open: root.opened, loadedPage: body.shell?.loadedPage ?? "",
                contentLoaded: !!body.shell, focus: body.shell?.Window.active ?? false,
                cmdline: {focused: body.shell?.commandLine.inputFocused ?? false, lines: body.shell?.commandLine.log.count ?? 0},
                bars: root.host.media.spectrum.length, player: !!root.host.media.active,
                theme: {base: Fart.Design.background.toString(), accent: Fart.Design.accent.toString(),
                    selected: Fart.Design.selected.toString(), opacity: Fart.Design.panelOpacity,
                    radius: Fart.Design.radiusPanel, blur: !!surface.BackgroundEffect.blurRegion},
                notifications: root.host.notifications.items.length, listening: root.host.notifications.available,
                core: root.core.connected, tasks: root.core.tasks.all.length,
                motion: {reduced: Cues.Motion.reduced, active: Cues.Motion.activeNames},
                overdrive: {driving: Cues.Motion.driving, drive: Math.round(Cues.Motion.drive * 1000) / 1000, loops: Cues.Motion.idleLoops, strata: Strata.live},
                surfaces: (root.retained ? 1 : 0) + satellites.surfaces, satellites: satellites.shown});
        }
    }
    Binding { target: body.shell; property: "spaceBelow"; value: heavy.showing; when: body.shell !== null }
    HeavyLayer {
        id: heavy
        opened: root.retained
        // The orbit's centre, in the panel's coordinates; only while the orbit is on the screen and nothing is flying past it.
        scene: {
            const shell = body.shell, orbit = shell?.orbit ?? null;
            if (!shell)
                return null;
            const theme = { edge: body.edge, full: surface.full, width: surface.width, height: surface.height, accent: Fart.Design.accent.toString(), second: Fart.Design.selected.toString(),
                            ink: Fart.Design.ink.toString(), background: Fart.Design.background.toString(), room: root.shownRoom, rooms: shell.navigationPages.map(p => p.id),
                            data: root.mediumData };
            if (!orbit || !shell.orbitOpen)
                return theme;
            const at = orbit.mapToItem(surface.contentItem, orbit.homeScreenX, orbit.homeScreenY);
            return Object.assign(theme, { cx: at.x, cy: at.y, radius: orbit.inner * 0.66 * orbit.camS, elevation: orbit.elevation });
        }
    }
    // Only levels and counts leave for the heavy process (view/strata/MediumLaws.js), and only those of the room in view, so a room's sampling never wakes for this.
    readonly property var mediumData: {
        const host = root.host, room = root.shownRoom;
        if (room === "media")
            return { playing: !!host.media?.active?.playing, spectrum: host.media?.spectrum ?? [] };
        if (room === "performance")
            return { cpu: (host.system?.cpu?.usage ?? 0) / 100, gpu: (host.system?.gpu?.usage ?? 0) / 100 };
        if (room === "workspaces")
            return { desks: (host.workspaces?.workspaces ?? []).filter(w => w.windowCount > 0).length || 1 };
        if (room === "tasks")
            return { tasks: root.core.tasks?.all?.filter(t => !t.done).length ?? 0 };
        if (room === "timers")
            return { running: !!root.core.timers?.anyRunning };
        if (room === "notifications")
            return { unread: host.notifications?.items?.length ?? 0 };
        return {};
    }
    PanelWindow {
        id: surface
        visible: root.retained
        // The panel sits on the bar's side of the screen, as the host's calendar does; fullscreen
        // (ViewState.fullscreen, F11) it covers the whole screen, bar included, on the overlay layer.
        readonly property bool full: ViewState.fullscreen
        anchors.top: full || body.edge !== "bottom"
        anchors.bottom: full || body.edge === "bottom"
        anchors.left: full
        anchors.right: full
        margins.top: full ? 0 : 8
        margins.bottom: full ? 0 : 8
        exclusionMode: full ? ExclusionMode.Ignore : ExclusionMode.Normal
        color: "transparent"
        implicitWidth: full ? screen.width : Math.min(1360, screen.width - 24)
        implicitHeight: full ? screen.height : Math.min(860, screen.height - (root.host.workspaces.monitors.find(m => m.name === screen.name)?.reservedTop || 0) - 32)
        WlrLayershell.namespace: "fart-control-centre"
        // The heavy layer takes the Top layer, under the panel.
        WlrLayershell.layer: full || heavy.up ? WlrLayer.Overlay : WlrLayer.Top
        WlrLayershell.keyboardFocus: root.opened && !body.shell?.externalDialogOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
        mask: Region { item: body.shape; radius: Fart.Design.radiusPanel * body.bodyScale }
        BackgroundEffect.blurRegion: Fart.Design.blur && surface.visible && !heavy.showing ? frameRegion : null
        Region { id: frameRegion; item: body.shape; radius: Fart.Design.radiusPanel * body.bodyScale }
        PanelBody {
            id: body
            width: surface.width
            height: surface.height
            host: root.host
            core: root.core
            context: context
            unfold: unfold
            retained: root.retained
            page: root.currentPage
            spaceShows: heavy.showing
            spaceOnOrbit: !!body.shell?.orbitOpen
            onLoaded: { coldProbe.mark("shell"); root.reportState(); }
            // The cold-start and warm-open budgets end here (DAILY_DRIVER §1); printed for the probe only.
            onInteractive: {
                coldProbe.interactive();
                if (coldProbe.enabled) console.log("FART_CMDLINE ready", Date.now());
            }
        }
    }
}
