import QtQuick
import qs.core.client
import qs.view.contract
import qs.view.shell
import qs.view.ui
import "TemporalMath.js" as Field

// One owner for the Timers room's state and actions, shared by both presentations (Angular's temporal field and
// Fluid's Confluence). Named after Astra's *Session controllers (HomeSession, MediaSession); the room's own word
// "session" still means a focus Session (M11), which this exposes as `active`.
Item {
    id: root
    required property HostAdapter host
    required property ShellContext shell
    required property CoreClient core
    property bool shown: false
    readonly property CoreTimers timers: core.timers
    readonly property string kind: ViewState.timerKind
    // The Session (M11): the running one, the last one's debrief, the streak and the presets, from the core.
    readonly property var active: core.sessionData?.active ?? null
    readonly property var debrief: core.sessionData?.last ?? null
    readonly property var streak: core.sessionData?.streak ?? null
    readonly property var presets: core.sessionData?.presets ?? []
    property real sessionNow: Date.now()
    Timer {
        interval: 1000
        repeat: true
        triggeredOnStart: true
        running: root.shown && root.active !== null
        onTriggered: root.sessionNow = Date.now()
    }
    readonly property real sessionLeft: active ? Math.max(0, (active.until - sessionNow) / 1000) : 0
    function lengthLabel(seconds) {
        return seconds % 3600 === 0 ? (seconds / 3600) + " h" : Math.round(seconds / 60) + " min";
    }
    readonly property bool running: kind === "session" ? active !== null : kind === "pomodoro" ? timers.pomodoroRunning : kind === "stopwatch"
                                                          ? timers.stopwatchRunning : timers.countdownRunning
    readonly property real seconds: kind === "session" ? (active ? sessionLeft : debrief?.seconds ?? 0) : kind === "pomodoro" ? timers.pomodoroSecondsLeft : kind === "stopwatch"
                                                          ? timers.stopwatchSeconds : timers.countdownSecondsLeft
    readonly property real duration: kind === "session" ? (active?.seconds ?? debrief?.planned ?? 0) : kind === "pomodoro" ? timers.pomodoroLapDuration : kind === "stopwatch"
                                                           ? 60 : timers.countdownDuration
    readonly property real fraction: kind === "stopwatch" ? (seconds % 60) / 60 : duration > 0 ? 1 - seconds / duration : 0
    readonly property bool completed: kind === "countdown" ? timers.countdownDone : kind === "pomodoro" && !!timers.pomodoroDone
    readonly property int cycles: timers.snap?.config?.pomodoro?.cycles ?? 4
    readonly property var modes: [
        { id: "countdown", name: "Countdown" },
        { id: "pomodoro", name: "Focus" },
        { id: "stopwatch", name: "Stopwatch" },
        { id: "session", name: "Session" }
    ]
    readonly property int modeIndex: Math.max(0, modes.findIndex(m => m.id === kind))
    readonly property var countdownMinutes: [5, 15, 25, 45]
    // Splits from the cumulative lap values, newest first, at most four.
    readonly property var splits: {
        const laps = timers.stopwatchLaps;
        const out = laps.map((total, i) => ({ number: i + 1, total, split: total - (i ? laps[i - 1] : 0) }));
        return out.slice(-4).reverse();
    }
    readonly property real fastest: splits.length > 1 ? Math.min(...timers.stopwatchLaps.map((t, i) => t - (i ? timers.stopwatchLaps[i - 1] : 0))) : -1
    function stamp(value) {
        return Clock.formatSeconds(value);
    }
    function splitStamp(split) {
        return stamp(split) + "." + (Math.floor(split * 100) % 100).toString().padStart(2, "0");
    }
    // What the hero line says above the clock, and under it.
    readonly property string heading: kind === "session" ? (active ? String(active.preset).toUpperCase() + " / SESSION · SILENT HELD"
                                                           : debrief ? "LAST / " + String(debrief.preset).toUpperCase() : "NO SESSION / PICK A LENGTH")
        : kind === "pomodoro" ? (timers.pomodoroBreak ? "REST" : "FOCUS") + " / CYCLE " + (timers.pomodoroCycle + 1)
        : kind === "stopwatch" ? "ELAPSED / NO DEADLINE" : "REMAINING / COUNTDOWN"
    readonly property string status: kind === "session" && !active && debrief
          ? (debrief.completed ? "SESSION COMPLETE" : "ENDED EARLY / " + Math.round(100 * debrief.seconds / Math.max(1, debrief.planned)) + "% OF THE PLAN")
          : completed ? "INTERVAL COMPLETE" : running ? "RUNNING" : "HELD"
    readonly property string readout: completed ? "DONE" : stamp(seconds)

    Binding { target: root.timers; property: "ticking"; value: root.shown }
    Binding { target: root.timers; property: "tickInterval"; value: 1000 }

    // The temporal field's sources: every clock with something to say, placed for Angular's field.
    readonly property var sources: {
        const a = [];
        if (timers.pomodoroRunning || timers.value("pomodoro") > 0 || timers.pomodoroDone)
            a.push({kind:"pomodoro",x:.16,y:.73,seconds:Math.ceil(timers.pomodoroSecondsLeft),duration:timers.pomodoroLapDuration,deadline:true,running:timers.pomodoroRunning,done:!!timers.pomodoroDone});
        if (timers.countdownDuration > 0)
            a.push({kind:"countdown",x:.72,y:.24,seconds:Math.ceil(timers.countdownSecondsLeft),duration:timers.countdownDuration,deadline:true,running:timers.countdownRunning,done:timers.countdownDone});
        if (timers.stopwatchRunning || timers.stopwatchSeconds > 0)
            a.push({kind:"stopwatch",x:.80,y:.79,seconds:Math.floor(timers.stopwatchSeconds),duration:0,deadline:false,running:timers.stopwatchRunning,done:false});
        if (active)
            a.push({kind:"session",x:.46,y:.52,seconds:Math.ceil(sessionLeft),duration:active.seconds,deadline:true,running:true,done:false});
        return a;
    }
    readonly property real remainingFraction: {
        const countdowns = sources.filter(a => a.deadline && (a.running || a.done));
        return countdowns.length ? Math.min(...countdowns.map(a => Field.fraction(a.seconds,a.duration))) : 1;
    }
    readonly property real collision: {
        const a = sources.filter(a => a.deadline && a.running);
        return a.length > 1 ? Math.abs(a[0].seconds-a[1].seconds) : -1;
    }
    readonly property string eventKey: sources.map(a => a.kind+":"+a.running+":"+a.done).join("/")
    readonly property string completionKey: [timers.snap?.countdown?.done?.at ?? "",timers.snap?.pomodoro?.done?.at ?? ""].join("/")

    // Actions, the same for both presentations.
    function setKind(id) { ViewState.timerKind = id; }
    function startCountdown(minutes) {
        shell.engagedTimerKind = "countdown";
        timers.startCountdown(minutes * 60);
    }
    function addMinute() { timers.addCountdown(60); }
    function startSession(name) { core.request("session.start", { preset: name }); }
    function endSession() { core.request("session.end", {}); }
    function dismissDebrief() { core.request("session.dismiss", {}); }
    function reset() { timers.reset(kind); }
    function lap() { timers.lap(); }
    function toggle() {
        shell.engagedTimerKind = kind;
        shell.toggleActiveTimer();
    }
    readonly property bool canToggle: timers.available && (kind !== "countdown" || timers.countdownDuration > 0)
}
