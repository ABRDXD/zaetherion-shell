import QtQuick
import Quickshell
import qs.view.contract
import qs.core.client
import qs.view.satellites

Scope {
    id: root
    required property HostAdapter host
    required property IslandQueue queue
    property CoreClient core: null
    property var startupNotice: null
    readonly property var durations: ({ charging: 2000, lowBattery: 5000, backend: 5000 })
    readonly property var recording: host.capture.available ? host.capture.recording : null
    readonly property var battery: host.power.battery
    property var previousBattery: null
    property var workspaceIds: []
    property bool memoryPinned: false
    readonly property var memory: host.system.memory
    readonly property bool pressureHigh: (memory?.pressureSomeAvg10 ?? 0) >= 1
    readonly property var notificationItems: host.notifications.items
    property var seenNotifications: []
    property bool ready: false
    readonly property var player: host.media.active
    readonly property string track: player ? JSON.stringify([player.id, player.artist, player.title]) : ""
    property string previousTrack: ""
    readonly property string workspace: host.workspaces.activeId
    property string previousWorkspace: ""

    // Z23 and the owner's S3 additions. Smaller numbers interrupt larger ones.
    readonly property var priority: ({
        critical: 0, done: 10, osd: 20, memory: 30, workspace: 31, notification: 40,
        recording: 50, charging: 60, track: 70, timer: 80
    })

    function notice(item): void {
        const critical = item.urgency === "critical";
        if (host.notifications.dnd && !critical) return;
        const kind = critical ? "critical" : "notification";
        queue.offer("notification:" + item.id, kind, priority[kind], item, 5000);
    }

    onNotificationItemsChanged: {
        if (!ready) return;
        for (const item of notificationItems) {
            if (!seenNotifications.includes(item.id)) notice(item);
        }
        seenNotifications = notificationItems.map(item => item.id);
    }

    Connections {
        target: root.host.osd
        function onEventChanged() {
            const value = root.host.osd.event;
            if (value && root.host.osd.available)
                root.queue.offer("osd", "osd", root.priority.osd, value, 1200);
        }
    }

    onTrackChanged: {
        if (ready && track && previousTrack && track !== previousTrack)
            queue.offer("track", "track", priority.track, player, 3000);
        previousTrack = track;
    }

    onWorkspaceChanged: {
        const changed = ready && previousWorkspace && workspace !== previousWorkspace;
        previousWorkspace = workspace;
        if (changed && workspaceIds.includes(workspace))
            queue.offer("workspace", "workspace", priority.workspace, { ids: workspaceIds, active: workspace }, 800);
    }

    function syncRecording(): void {
        if (recording?.active)
            queue.offer("recording", "recording", priority.recording, recording, null);
        else queue.remove("recording");
    }
    onRecordingChanged: if (ready) syncRecording()

    onBatteryChanged: {
        const previous = previousBattery;
        previousBattery = battery;
        if (!ready || !previous?.available || !battery?.available) return;
        if (battery.charging && !previous.charging)
            queue.offer("charging", "charging", priority.charging, { label: "> POWER · CHARGING" }, durations.charging);
        if (battery.pluggedIn) return;
        const threshold = [0.05, 0.1, 0.2].find(level => battery.level <= level && previous.level > level);
        if (threshold === undefined || (host.notifications.dnd && threshold > 0.05)) return;
        queue.offer("low-battery", "low-battery", threshold === 0.05 ? priority.critical : priority.notification,
            { label: "> BATTERY · " + Math.round(battery.level * 100) + "%" }, durations.lowBattery);
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
            queue.offer("done", "done", priority.done, { label: "> TIMER · " + state.doneText }, null);
        } else queue.remove("done");
        if (state?.timerDue) {
            queue.offer("timer", "timer", priority.timer,
                { label: "> " + state.timerLabel + " · " + state.timerText, task: state.taskText }, null);
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
        seenNotifications = notificationItems.map(item => item.id);
        previousTrack = track;
        previousWorkspace = workspace;
        previousBattery = battery;
        ready = true;
        syncMemory();
        syncRecording();
        syncStartupNotice();
        syncTimer();
        syncDebrief();
    }
}
