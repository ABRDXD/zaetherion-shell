import QtQuick
import Quickshell
import qs.core.client
import qs.adapters.fixture
import qs.adapters.serpantinum
import qs.view.cues
import qs.view.shell
import qs.view.ui as Fart

// The offscreen QPA has no PanelWindow backend. Exercise the real room loader
// and CoreClient in a normal window. Report the page only after it has loaded.
FloatingWindow {
    id: window
    implicitWidth: 1120
    implicitHeight: 760
    property bool opened: false
    property string page: "home"
    // For harnesses that drive this view (tools/cmdtest).
    readonly property alias body: body
    readonly property alias unfold: unfold
    readonly property alias client: client
    readonly property alias fixture: fixture
    // The Overlay's unfold. FART_MOTION=serpantinum applies the host profile (static data).
    Unfold { id: unfold; on: window.opened }
    SerpantinumMotion { id: serpantinum }
    Binding { target: Motion; property: "profile"; value: serpantinum.roles; when: Quickshell.env("FART_MOTION") === "serpantinum" }
    // As Overlay does: reduced motion follows the FART preference, and Overdrive the private core's lease.
    Binding { target: Motion; property: "reduced"; value: !ViewState.motionEnabled }
    Binding { target: Motion; property: "overdrive"; value: client.overdriveData?.effective === "active" }
    Binding { target: Motion; property: "seen"; value: window.retained }
    // FART_REDUCED=1 and FART_AMBIENT=0 set the user's own preferences (desktop_idle, desktop_canvas),
    // so a shell that binds its gates to them is measured the way the user would switch them.
    function applyPreferences() {
        if (Quickshell.env("FART_REDUCED") === "1") ViewState.motionEnabled = false;
        if (Quickshell.env("FART_AMBIENT") === "0") ViewState.ambientEnabled = false;
    }
    Connections { target: ViewState; function onLoadedChanged() { window.applyPreferences(); } }
    readonly property bool retained: opened || unfold.value > 0
    // FART_KEEP_MAPPED=1 keeps the window mapped once shown, so folding and unfolding do not
    // map a new toplevel (a focus change the interaction observer would count).
    readonly property bool keepMapped: Quickshell.env("FART_KEEP_MAPPED") === "1"
    property bool shown: false
    onRetainedChanged: {
        if (retained) shown = true;
        else closedReport.restart();
    }
    // The cue activity count once closed and settled (the fold's own animation stops a turn later).
    Timer {
        id: closedReport
        interval: 500
        onTriggered: console.log("FART_MOTION closed", Motion.active, JSON.stringify(Motion.activeNames))
    }
    visible: retained || (keepMapped && shown)
    color: "transparent"

    FixtureAdapter { id: fixture }
    // Cold-start phase markers (cold_breakdown.py, FART_COLD_PROBE=1 only), wall-clock ms.
    ColdProbe {
        id: coldProbe
        window: body.Window.window
        inputFocused: body.shell?.commandLine.inputFocused ?? false
    }
    Component.onCompleted: {
        Host.adapter = fixture;
        Fart.Design.source = fixture.palette;
        coldProbe.mark("created");
        // FART_IDLE_MS (desktop_idle --idle-ms): the shared idle clock's interval, for a cost-versus-rate sweep.
        if (Quickshell.env("FART_IDLE_MS"))
            Motion.idleInterval = Number(Quickshell.env("FART_IDLE_MS"));
        if (window.playing) {
            fixture.media.active = Object.assign({}, fixture.media.active, { playing: true });
            fixture.media.positionStamp = Date.now();
        }
    }
    // FART_FIXTURE_PLAYING=1 (desktop_idle --playing): the fixture player plays, and a spectrum arrives as the
    // real adapter's does, 56 bins at 30 fps (tools/cava.conf), only while a "spectrum" lease is held.
    readonly property bool playing: Quickshell.env("FART_FIXTURE_PLAYING") === "1"
    Timer {
        interval: 33
        repeat: true
        running: window.playing && fixture.media.holds("spectrum")
        property real phase: 0
        onRunningChanged: if (!running) fixture.media.spectrum = []
        onTriggered: {
            phase += 0.21;
            const bins = [];
            for (let i = 0; i < 56; i++)
                bins.push(Math.max(0, Math.min(1, 0.45 + 0.35 * Math.sin(phase + i * 0.37) * Math.cos(phase * 0.53 - i * 0.11))));
            fixture.media.spectrum = bins;
        }
    }
    ShellContext { id: context; panelOpen: window.opened; core: client }
    CoreClient {
        id: client
        host: fixture
        onConnectedChanged: if (connected) window.report()
        onCommand: (action, targetPage, from, extra) => window.handle(action, targetPage, from, extra)
    }
    function handle(action, targetPage, from, extra) {
        coldProbe.mark("command");
        if (action === "close" || (action === "toggle" && window.opened)) {
            // The cue activity count at the end of an open stretch (docs/CUES.md §10.5).
            console.log("FART_MOTION open", Motion.active, JSON.stringify(Motion.activeNames));
            if (probe.wanted && window.keepMapped) console.log("FART_PAGE fold", probe.index());
            window.opened = false;
            probe.flush();
        } else {
            // Opening from closed is the unfold segment; otherwise the room's. The marker
            // comes first so the load line below belongs to its segment.
            const reopening = !window.opened && window.keepMapped;
            if (probe.wanted && reopening) probe.flush();
            if (probe.wanted) console.log("FART_PAGE", reopening ? "unfold" : targetPage || window.page, probe.index());
            window.applyPreferences();
            const started = Date.now();
            // The origin as Overlay picks it, with this window standing in for a centred panel.
            if (!window.opened && unfold.value === 0)
                body.origin = body.originFrom(from, ((window.screen?.width ?? window.width) - window.width) / 2);
            window.page = targetPage || window.page;
            body.show(window.page);
            // desktop_idle's "orbit" pseudo-room (sent as the screen, which this floating window ignores): the room opens with the orbit over it.
            if (extra?.screen === "fart:orbit" && body.shell && body.shell.orbitOpen === false)
                body.shell.toggleOrbit();
            if (extra?.fly !== undefined)
                body.shell?.flyTo(extra.fly);
            window.opened = true;
            body.armInteractive();
            body.focusCommandLine();
            // Whole ms: the synchronous part of the command (room destroyed and created).
            if (probe.wanted) console.log("FART_LOAD", window.page, Date.now() - started);
            coldProbe.handled();
        }
        window.report();
    }
    // The panel's own close paths (Escape on an empty command line, Close) fold it as Overlay does.
    Connections {
        target: Host
        function onCloseRequested() { window.handle("close", "", null, {}); }
    }
    Connections {
        target: Fart.Feedback
        function onCue(name) { client.notify("sfx.play", { cue: name }); }
    }
    Connections {
        target: body.shell?.commandLine ?? null
        function onIdleChanged() { window.report(); }
    }
    function report() {
        if (client.connected && (!opened || body.shell?.loadedPage === page))
            client.notify("view.state", {open: opened, page: page, cmdlineIdle: opened && (body.shell?.commandLine.idle ?? false)});
    }
    // Sub-millisecond frame intervals for desktop measurement (FART_FRAME_PROBE=1 only).
    // A running FrameAnimation keeps the render loop producing a frame every vsync, so an
    // interval longer than 1.5 refresh periods is a missed presentation. Intervals are kept
    // in memory and printed on close and reopen, so the probe adds no work at navigation time.
    FrameAnimation {
        id: probe
        readonly property bool wanted: Quickshell.env("FART_FRAME_PROBE") === "1"
        property var frames: []
        property int flushed: 0
        // A global frame index, so markers stay valid across flushes. A function, because
        // push() does not notify a binding on frames.length.
        function index() { return flushed + frames.length; }
        running: wanted && window.visible
        onTriggered: frames.push([window.page, Math.round(frameTime * 1e6) / 1000])
        function flush() {
            if (!wanted || frames.length === 0) return;
            console.log("FART_FRAMES " + JSON.stringify(frames));
            flushed += frames.length;
            frames = [];
        }
    }

    // Desktop command-line measurement (desktop_cmdline.py): FART_CMDLINE_SCRIPT is a JSON list of lines,
    // typed at 30 ms per character with Enter after each, FART_CMDLINE_DELAY ms after the first open
    // settles. A "cmdline" marker starts the segment, so its frames are measured on their own.
    readonly property var script: JSON.parse(Quickshell.env("FART_CMDLINE_SCRIPT") || "[]")
    Timer {
        id: scriptStart
        interval: Number(Quickshell.env("FART_CMDLINE_DELAY") || 3000)
        running: window.script.length > 0 && !typist.begun && window.opened && body.shell?.loadedPage === window.page
        onTriggered: {
            if (probe.wanted) console.log("FART_PAGE", "cmdline", probe.index());
            typist.begun = true;
            typist.start();
        }
    }
    Timer {
        id: typist
        property bool begun: false
        property int line: 0
        property int character: 0
        interval: 30
        repeat: true
        onTriggered: {
            const commandLine = body.shell?.commandLine;
            const text = window.script[line];
            if (!commandLine || text === undefined) {
                stop();
                return;
            }
            // An ambiguous line comes back for refining; the script clears it, as Escape would.
            if (character === 0 && commandLine.text !== "")
                commandLine.cancel();
            if (character < text.length) {
                commandLine.typeIn(text[character++]);
                return;
            }
            commandLine.run();
            line++;
            character = 0;
            if (line >= window.script.length) {
                stop();
                console.log("FART_CMDLINE done");
            }
        }
    }
    // Move measurement and demonstration (desktop_canvas.py): FART_CANVAS_SCRIPT is a JSON list of steps, run
    // one every FART_CANVAS_STEP ms (default 1200), FART_CANVAS_DELAY ms (default 2500) after the first open:
    //   "orbit" / "back" the orbit opens / closes (Shell.toggleOrbit, Shell.escapeKey);
    //   "<page>"         fly to that room through the orbit, as a room shortcut does;
    //   {"call": name, "args": [...], "label": x}   any Shell function a prototype adds (a pan, a zoom); a dotted
    //                    name reaches into Shell ("orbit.move" calls Shell.orbit.move);
    //   {"set": "orbit.hoverIndex", "value": 3, "label": x}   assigns a property the same way (a hover stand-in).
    // Each step starts its own FART_PAGE segment (orbit_open, orbit_close, travel_<page>, or the label), and prints
    // the cue activity after it settles, so idle loops and stuck cues show up per step.
    readonly property var canvasScript: JSON.parse(Quickshell.env("FART_CANVAS_SCRIPT") || "[]")
    Timer {
        id: canvasRunner
        property int step: 0
        interval: Number(Quickshell.env("FART_CANVAS_STEP") || 1200)
        repeat: true
        onTriggered: {
            const shell = body.shell;
            if (step > 0)
                console.log("FART_CANVAS settled", step - 1, Motion.active, JSON.stringify(Motion.activeNames));
            const item = window.canvasScript[step];
            if (!shell || item === undefined) {
                stop();
                console.log("FART_CANVAS done");
                return;
            }
            step++;
            const label = item === "orbit" ? "orbit_open" : item === "back" ? "orbit_close" : typeof item === "string" ? "travel_" + item
                : (item.label || item.call || item.set);
            // A dotted path from Shell: the object that holds the last name, and that name.
            const path = typeof item === "object" ? String(item.call || item.set).split(".") : [];
            const owner = path.slice(0, -1).reduce((o, k) => o?.[k], shell);
            const key = path[path.length - 1];
            if (typeof item === "object" && (!owner || (item.call && typeof owner[key] !== "function") || (item.set && !(key in owner)))) {
                console.log("FART_CANVAS missing", item.call || item.set);
                return;
            }
            if (probe.wanted) console.log("FART_PAGE", label, probe.index());
            const started = Date.now();
            if (item === "orbit") {
                if (!shell.orbitOpen) shell.toggleOrbit();
            } else if (item === "back") {
                if (shell.orbitOpen) shell.escapeKey();
            } else if (typeof item === "string") {
                window.page = item;
                body.show(item);
            } else if (item.set) {
                owner[key] = item.value;
            } else {
                owner[key](...(item.args || []));
            }
            // The synchronous part, and the anchor desktop_stats needs to record this segment's polish.
            if (probe.wanted) console.log("FART_LOAD", label, Date.now() - started);
        }
    }
    Timer {
        interval: Number(Quickshell.env("FART_CANVAS_DELAY") || 2500)
        running: window.canvasScript.length > 0 && window.opened
        onTriggered: canvasRunner.start()
    }
    // The body exactly as Overlay draws it, without the layer surface.
    PanelBody {
        id: body
        anchors.fill: parent
        host: fixture
        core: client
        context: context
        unfold: unfold
        retained: window.retained
        keepShell: Quickshell.env("FART_KEEP_SHELL") !== "0"
        page: window.page
        onLoaded: { coldProbe.mark("shell"); window.report(); }
        // Wall-clock ms, so a harness can subtract its own send time (DAILY_DRIVER §1).
        onInteractive: {
            coldProbe.interactive();
            console.log("FART_CMDLINE ready", Date.now());
        }
    }
    Connections {
        target: body.shell
        function onLoadedPageChanged() {
            if (body.shell.loadedPage !== "") coldProbe.mark("room");
            Qt.callLater(window.report);
        }
    }
}
