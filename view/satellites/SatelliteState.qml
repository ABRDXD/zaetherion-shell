import QtQuick
import qs.core.client
import qs.view.contract
import qs.view.cues

// What the satellites show and when (DAILY_DRIVER §5, D18), as plain state: no surface, no drawing.
// Satellites never show while the panel is open (it shows the same thing) or while the focused
// screen has a fullscreen window. Each kind is due only while it has something to show, so with
// nothing due there is no surface, timer or animation.
QtObject {
    id: root
    required property CoreClient core
    required property HostAdapter host
    property bool panelOpen: false
    // Wall-clock ms; the harness replaces it.
    property var clock: () => Date.now()

    readonly property var workspaces: host.workspaces
    readonly property bool fullscreen: workspaces.windows.some(w => w.fullscreen && w.monitor === workspaces.focusedScreen)
    readonly property bool suppressed: panelOpen || fullscreen
    readonly property var session: core.sessionData?.active ?? null

    // Timer and session: the remaining time of the engaged one, at minute resolution
    // (Q10), per second in the last minute. One single-shot wake per displayed change.
    readonly property var snap: core.timersData
    property double now: clock()
    onSnapChanged: now = clock()
    readonly property string engaged: snap?.countdown?.running ? "countdown" : snap?.pomodoro?.running ? "pomodoro" : session ? "session" : ""
    readonly property real remaining: {
        if (engaged === "session")
            return Math.max(0, (session.until - now) / 1000);
        if (engaged === "")
            return 0;
        const timer = snap[engaged];
        return Math.max(0, timer.duration - timer.elapsed - (now - snap.at) / 1000);
    }
    readonly property bool timerDue: !suppressed && engaged !== "" && remaining > 0
    readonly property string timerText: remaining > 60 ? Math.ceil(remaining / 60) + "′" : "0:" + String(Math.ceil(remaining)).padStart(2, "0")
    readonly property string timerLabel: engaged === "pomodoro" ? (snap.pomodoro.phase === "focus" ? "FOCUS" : "BREAK") : engaged === "session" ? String(session.preset).toUpperCase() : "TIMER"
    // The active task, during a focus pomodoro or a session: the default list's first open task.
    readonly property string taskText: {
        if (!(engaged === "session" || (engaged === "pomodoro" && snap.pomodoro.phase === "focus")))
            return "";
        const task = (core.tasksData?.tasks ?? []).find(t => t.list === "default" && !t.done);
        return task ? task.text : "";
    }
    // Milliseconds until the displayed text next changes.
    readonly property int nextChange: {
        const unit = remaining > 60 ? 60 : 1;
        const steps = Math.ceil(remaining / unit);
        return Math.max(20, Math.round((remaining - (steps - 1) * unit) * 1000));
    }
    property Timer wake: Timer {
        running: root.timerDue
        interval: root.nextChange
        onTriggered: {
            root.now = root.clock();
            if (root.timerDue)
                restart();
        }
    }

    // DONE: a finished countdown or pomodoro phase, kept by the core until `timer.ack` (so a DONE
    // that lands while the view is reaped is shown when the core spawns it).
    readonly property bool countdownDone: !!snap?.countdown?.done
    readonly property var phaseDone: snap?.pomodoro?.done ?? null
    readonly property bool doneDue: !suppressed && (countdownDone || phaseDone !== null)
    readonly property string doneText: countdownDone ? "DONE" : phaseDone?.phase === "focus" ? "FOCUS DONE" : "BREAK DONE"
    function ack() {
        core.timers.ack();
    }

    // Track change (Q8, committed): `artist — title` for `dwell`. Two sources, one label: the core's
    // `track` topic (MPRIS, also when it spawned this view for the change) and, without the core's
    // monitor, the adapter's active player. The first track the adapter shows is not a change, and a
    // core snapshot older than `dwell` is not news.
    readonly property var player: host.media.active
    readonly property string mediaKey: player ? [player.artist, player.title].filter(s => !!s).join(" — ") : ""
    readonly property var coreTrack: core.trackData ?? null
    property string lastMedia: ""
    property double lastCoreAt: 0
    property string trackText: ""
    property bool trackShowing: false
    function announce(key) {
        if (key === "" || (trackShowing && key === trackText))
            return;
        trackText = key;
        trackShowing = true;
        dwell.restart();
    }
    onMediaKeyChanged: {
        if (mediaKey === "" || mediaKey === lastMedia)
            return;
        const first = lastMedia === "";
        lastMedia = mediaKey;
        if (!first)
            announce(mediaKey);
    }
    onCoreTrackChanged: {
        const at = coreTrack?.at ?? 0;
        if (!at || at === lastCoreAt)
            return;
        lastCoreAt = at;
        if (clock() - at < Motion.dwell)
            announce([coreTrack.artist, coreTrack.title].filter(s => !!s).join(" — "));
    }
    Component.onCompleted: {
        lastMedia = mediaKey;
        lastCoreAt = coreTrack?.at ?? 0;
        if (lastCoreAt && clock() - lastCoreAt < Motion.dwell)
            announce([coreTrack.artist, coreTrack.title].filter(s => !!s).join(" — "));
    }
    property Timer dwell: Timer {
        interval: Motion.dwell
        onTriggered: root.trackShowing = false
    }
    readonly property bool trackDue: trackShowing && !suppressed && !session

    readonly property bool anyDue: timerDue || doneDue || trackDue
}
