import QtQuick
import Quickshell

// Timers as the rooms read them. The core never ticks for display: while a visible element holds
// `ticking`, running values are extrapolated from the snapshot stamp, as media position is.
Scope {
    id: root
    required property var core
    property bool ticking: false
    property int tickInterval: 200
    property double now: Date.now()
    readonly property var snap: core.timersData
    readonly property bool available: core.connected && !!snap
    readonly property bool anyRunning: pomodoroRunning || stopwatchRunning || countdownRunning

    readonly property bool pomodoroRunning: snap?.pomodoro.running ?? false
    readonly property string pomodoroPhase: snap?.pomodoro.phase ?? "focus"
    readonly property bool pomodoroBreak: pomodoroPhase !== "focus"
    readonly property int pomodoroCycle: snap?.pomodoro.cycle ?? 0
    readonly property real pomodoroLapDuration: snap?.pomodoro.duration ?? 0
    readonly property real pomodoroSecondsLeft: Math.max(0, pomodoroLapDuration - value("pomodoro"))
    readonly property int focusTime: snap?.config.pomodoro.focus ?? 1500
    readonly property int breakTime: snap?.config.pomodoro["break"] ?? 300

    readonly property bool stopwatchRunning: snap?.stopwatch.running ?? false
    readonly property real stopwatchSeconds: value("stopwatch")
    readonly property var stopwatchLaps: snap?.stopwatch.laps ?? []

    readonly property bool countdownRunning: snap?.countdown.running ?? false
    readonly property real countdownDuration: snap?.countdown.duration ?? 0
    readonly property real countdownSecondsLeft: Math.max(0, countdownDuration - value("countdown"))
    readonly property bool countdownDone: !!snap?.countdown.done
    // {phase, next, at, late}: the last pomodoro phase that ended, until acknowledged
    readonly property var pomodoroDone: snap?.pomodoro.done ?? null

    onSnapChanged: now = Date.now()

    function value(kind) {
        const timer = snap?.[kind];
        if (!timer) return 0;
        return timer.elapsed + (timer.running ? Math.max(0, (now - snap.at) / 1000) : 0);
    }
    function toggle(kind) { core.request("timer.toggle", { kind: kind }); }
    function reset(kind) { core.request("timer.reset", { kind: kind }); }
    function startCountdown(seconds) { core.request("timer.start", { kind: "countdown", seconds: seconds }); }
    function addCountdown(seconds) { core.request("timer.add", { kind: "countdown", seconds: seconds }); }
    function lap() { core.request("timer.lap"); }
    // No kind clears every DONE (the satellite's click); "countdown" or "pomodoro" clears one.
    function ack(kind) { core.request("timer.ack", kind ? { kind: kind } : {}); }

    Timer {
        interval: root.tickInterval
        running: root.ticking && root.anyRunning
        repeat: true
        onTriggered: root.now = Date.now()
    }
}
