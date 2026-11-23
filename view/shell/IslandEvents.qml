import QtQuick
import Quickshell
import qs.view.contract
import qs.core.client
import qs.view.satellites
import qs.view.ui
import "IslandTiming.js" as Timing
import "NetWords.js" as NetWords

Scope {
    id: root
    required property HostAdapter host
    required property IslandQueue queue
    property CoreClient core: null
    property var startupNotice: null
    // Z174: FART covers the island; an OSD change is handed out through `coveredOsd` instead of being queued.
    property bool covered: false
    property int osdDwell: Timing.osd
    signal coveredOsd(var value)
    // How long a notification stays: the owner's choice in FART's Notifications tab (Z207), Z200's 1 s without one.
    readonly property int noticeMs: core?.islandData?.noticeMs ?? Timing.notification
    readonly property var durations: ({ charging: Timing.charging, lowBattery: Timing.lowBattery, backend: Timing.backend,
                                        notification: noticeMs })
    // Z175: the island shows a non-critical notification for at most this long, whatever its sender asked for.
    readonly property int notificationCap: Math.max(Timing.notificationCap, noticeMs)
    // The core records (Z221); a host's own recorder still shows when the core has no recording to report.
    readonly property var recording: core?.captureData?.recording ?? (host.capture.available ? host.capture.recording : null)
    readonly property var battery: host.power.battery
    property var previousBattery: null
    property var workspaceIds: []
    property bool memoryPinned: false
    readonly property var memory: host.system.memory
    readonly property bool pressureHigh: (memory?.pressureSomeAvg10 ?? 0) >= 1
    readonly property var notificationItems: host.notifications.items
    // id → arrival time. A replace-id keeps the id and moves the time.
    property var seenNotifications: ({})
    property bool ready: false
    readonly property var player: host.media.active
    readonly property string track: player ? JSON.stringify([player.id, player.artist, player.title]) : ""
    property string previousTrack: ""
    readonly property string workspace: host.workspaces.activeId
    property string previousWorkspace: ""

    // Z23 and the owner's S3 additions. Smaller numbers interrupt larger ones.
    // held: a face the owner opened (tray menu, session card); only critical interrupts it (Z161).
    readonly property var priority: ({
        critical: 0, held: 5, done: 10, osd: 20, memory: 30, workspace: 31, notification: 40,
        recording: 50, charging: 60, track: 70, timer: 80
    })

    function notice(item): void {
        const critical = item.urgency === "critical";
        if (host.notifications.dnd && !critical) return;
        const kind = critical ? "critical" : "notification";
        // Only a live notification can be answered from here (a mirrored or restored one cannot).
        const shown = item.live === false ? Object.assign({}, item, { actions: [], reply: "" }) : item;
        queue.offer("notification:" + item.id, kind, priority[kind], shown, showTime(item));
    }
    // The item's own showing time (contract: 0 = until dismissed, absent or negative = ours). A sender's long time is
    // honoured up to notificationCap (Z175); a critical one is not capped. The Inbox keeps the item either way.
    function showTime(item): var {
        if (item.timeout > 0) return item.urgency === "critical" ? item.timeout : Math.min(item.timeout, notificationCap);
        // Critical stays until dismissed. A sender's "never expire" (0) is the Inbox's business: on the island it gets our
        // time like any other (Z200), since many apps send 0 for an everyday notice.
        return item.urgency === "critical" ? null : durations.notification;
    }
    function arrivals(): var {
        const times = {};
        for (const item of notificationItems) times[item.id] = item.time;
        return times;
    }

    onNotificationItemsChanged: {
        if (!ready) return;
        const now = arrivals();
        for (const item of notificationItems) {
            if (!(item.id in seenNotifications) || seenNotifications[item.id] !== item.time) notice(item);   // new or replaced
        }
        for (const id of Object.keys(seenNotifications)) {
            if (!(id in now)) queue.remove("notification:" + id);   // closed by its sender, or dismissed elsewhere
        }
        seenNotifications = now;
    }

    Connections {
        target: root.host.osd
        function onEventChanged() {
            const value = root.host.osd.event;
            if (value && root.host.osd.available) {
                // Z174: covered by FART, the OSD goes to FART's header, not into the queue.
                if (root.covered) root.coveredOsd(value);
                else root.queue.offer("osd", "osd", root.priority.osd, value, root.osdDwell);
                Feedback.play("osd.tick");
            }
        }
    }

    onTrackChanged: {
        if (ready && track && previousTrack && track !== previousTrack)
            queue.offer("track", "track", priority.track, player, Timing.track);
        previousTrack = track;
    }

    // id → window count, for the workspace instrument (a workspace with more windows is a larger world, Z199).
    function windowCounts(): var {
        const counts = {};
        for (const space of host.workspaces.workspaces ?? [])
            counts[String(space.id)] = Number(space.windowCount ?? 0);
        return counts;
    }

    onWorkspaceChanged: {
        const changed = ready && previousWorkspace && workspace !== previousWorkspace;
        previousWorkspace = workspace;
        if (changed && workspaceIds.includes(workspace))
            queue.offer("workspace", "workspace", priority.workspace,
                        { ids: workspaceIds, active: workspace, windows: windowCounts() }, Timing.workspace);
    }

    function syncRecording(): void {
        if (recording?.active)
            queue.offer("recording", "recording", priority.recording, recording, null);
        else queue.remove("recording");
    }
    onRecordingChanged: if (ready) syncRecording()

    // A Wi-Fi password or a Bluetooth pairing asked for while FART is closed (docs/NET_BT.md §5): one event each, held
    // for as long as the question is open; a click opens FART's settings where it is answered. FART never opens by
    // itself. The secret itself is never on the island.
    readonly property var wifiPrompt: host.network.prompt ?? null
    readonly property var pairingPrompt: host.bluetooth.pairing ?? null
    onWifiPromptChanged: syncPrompts()
    onPairingPromptChanged: syncPrompts()
    function syncPrompts(): void {
        if (wifiPrompt)
            queue.offer("prompt:wifi", "prompt", priority.notification,
                { label: "> WI-FI · PASSWORD", task: NetWords.prompt(wifiPrompt), section: "wifi" }, null);
        else queue.remove("prompt:wifi");
        if (pairingPrompt)
            queue.offer("prompt:bluetooth", "prompt", priority.notification,
                { label: "> BLUETOOTH · PAIRING", task: NetWords.pairing(pairingPrompt)?.line ?? "", section: "bluetooth" }, null);
        else queue.remove("prompt:bluetooth");
    }

    onBatteryChanged: {
        const previous = previousBattery;
        previousBattery = battery;
        if (!ready || !previous?.available || !battery?.available) return;
        if (battery.charging && !previous.charging)
            queue.offer("charging", "charging", priority.charging, { label: "> POWER · CHARGING" }, durations.charging);
        if (battery.pluggedIn !== previous.pluggedIn)
            Feedback.play(battery.pluggedIn ? "power.plug" : "power.unplug");
        if (battery.pluggedIn) return;
        const threshold = [0.05, 0.1, 0.2].find(level => battery.level <= level && previous.level > level);
        if (threshold === undefined || (host.notifications.dnd && threshold > 0.05)) return;
        queue.offer("low-battery", "low-battery", threshold === 0.05 ? priority.critical : priority.notification,
            { label: "> BATTERY · " + Math.round(battery.level * 100) + "%" }, durations.lowBattery);
        Feedback.play("battery.low");
    }

    // The network coming and going is heard, not shown (the island's glyph already says it). Not at start, and not
    // while the source is away (DMS restarting is not the network going down): only a known state that changes.
    readonly property var online: host.network.available ? host.network.connected === true : null
    property var lastOnline: null
    onOnlineChanged: {
        if (online === null) return;
        if (ready && lastOnline !== null && online !== lastOnline)
            Feedback.play(online ? "net.up" : "net.down");
        lastOnline = online;
    }

    function syncStartupNotice(): void {
        if (!ready || !startupNotice) return;
        if (startupNotice.kind === "backend")
            queue.offer("backend", "backend", priority.notification, startupNotice, durations.backend);
        else if (startupNotice.kind === "resident")
            queue.offer("resident", "resident", priority.notification, startupNotice, null);
    }

    onStartupNoticeChanged: syncStartupNotice()

    LazyLoader {
        id: timerSource
        active: root.core !== null
        SatelliteState { core: root.core; host: root.host }
    }
    Connections {
        target: timerSource.item
        function onTimerDueChanged() { root.syncTimer(); }
        function onTimerTextChanged() { root.syncTimer(); }
        function onTaskTextChanged() { root.syncTimer(); }
        function onDoneDueChanged() { root.syncTimer(); }
        function onDoneTextChanged() { root.syncTimer(); }
    }
    Connections {
        target: root.core
        function onSessionDataChanged() { root.syncDebrief(); }
    }
    function syncDebrief(): void {
        const session = core?.sessionData;
        if (session?.last && !session.active) {
            queue.offer("debrief", "debrief", priority.timer,
                { label: "> SESSION · DEBRIEF", seconds: session.last.seconds,
                  tasks: session.last.tasks, streak: session.streak?.current }, null);
        } else queue.remove("debrief");
    }

    function syncTimer(): void {
        const state = timerSource.item;
        if (state?.doneDue) {
            queue.offer("done", "done", priority.done, { label: "> TIMER · " + state.doneText, phase: state.doneText }, null);
        } else queue.remove("done");
        if (state?.timerDue) {
            queue.offer("timer", "timer", priority.timer,
                { label: "> " + state.timerLabel + " · " + state.timerText, phase: state.timerLabel, remaining: state.timerText, task: state.taskText }, null);
        } else queue.remove("timer");
    }

    function syncMemory(): void {
        if (!ready) return;
        if (pressureHigh || memoryPinned) {
            recover.stop();
            queue.offer("memory", "memory", priority.memory, memory, null);
        } else if (queue.entries.some(event => event.id === "memory") && !recover.running) {
            recover.start();
        }
    }
    onMemoryChanged: syncMemory()
    onPressureHighChanged: syncMemory()
    onMemoryPinnedChanged: syncMemory()

    Timer {
        id: recover
        interval: 10000
        onTriggered: root.queue.remove("memory")
    }

    Component.onCompleted: {
        seenNotifications = arrivals();
        previousTrack = track;
        previousWorkspace = workspace;
        previousBattery = battery;
        ready = true;
        syncMemory();
        syncRecording();
        syncPrompts();
        syncStartupNotice();
        syncTimer();
        syncDebrief();
    }
}
