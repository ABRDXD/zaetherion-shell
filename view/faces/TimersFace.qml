import qs.core.client
import QtQuick

// Timers as a planet: the timer that ends next (countdown or focus), else the stopwatch, in whole
// seconds. It steps exactly when the shown second changes, by a single-shot timer re-armed each time,
// and only while something runs and the face is live. With nothing running it never wakes.
Face {
    id: root
    required property CoreClient core
    readonly property CoreTimers timers: core.timers
    readonly property var snap: timers.snap
    // The face's own clock, separate from CoreTimers.now (the Timers room sets that one's rate).
    property double now: Date.now()
    onSnapChanged: { now = Date.now(); arm(); }
    onLiveChanged: { now = Date.now(); arm(); }

    function value(kind) {
        const timer = snap?.[kind];
        if (!timer)
            return 0;
        return timer.elapsed + (timer.running ? Math.max(0, (now - snap.at) / 1000) : 0);
    }
    // What the face shows: { kind, seconds, down, note }. `down` counts toward zero (shown rounded up).
    readonly property var shown: {
        if (!timers.available)
            return { kind: "", seconds: 0, down: false, note: "OFFLINE" };
        if (timers.countdownDone || timers.pomodoroDone)
            return { kind: "done", seconds: 0, down: true, note: timers.countdownDone ? "COUNTDOWN DONE" : "PHASE DONE" };
        const cd = { kind: "countdown", seconds: Math.max(0, timers.countdownDuration - value("countdown")), down: true, note: "COUNTDOWN" };
        const pomo = { kind: "pomodoro", seconds: Math.max(0, timers.pomodoroLapDuration - value("pomodoro")), down: true,
                       note: (timers.pomodoroBreak ? "BREAK" : "FOCUS") + (timers.pomodoroCycle > 0 ? " " + timers.pomodoroCycle : "") };
        const sw = { kind: "stopwatch", seconds: value("stopwatch"), down: false, note: "STOPWATCH" };
        if (timers.countdownRunning && timers.pomodoroRunning)
            return cd.seconds <= pomo.seconds ? cd : pomo;
        if (timers.countdownRunning)
            return cd;
        if (timers.pomodoroRunning)
            return pomo;
        if (timers.stopwatchRunning)
            return sw;
        // Paused, with time on it: the same figure, marked as held.
        if (value("countdown") > 0 && timers.countdownDuration > 0)
            return Object.assign(cd, { note: "HELD" });
        if (value("pomodoro") > 0 && timers.pomodoroLapDuration > 0)
            return Object.assign(pomo, { note: "HELD" });
        if (sw.seconds > 0)
            return Object.assign(sw, { note: "HELD" });
        return { kind: "idle", seconds: timers.focusTime, down: true, note: "IDLE" };
    }
    readonly property bool running: timers.anyRunning && shown.kind !== "done" && shown.note !== "HELD" && shown.kind !== "idle"
    readonly property int whole: shown.down ? Math.ceil(shown.seconds - 1e-6) : Math.floor(shown.seconds + 1e-6)
    alarm: shown.kind === "done"

    function clock(seconds) {
        const s = Math.max(0, seconds);
        const two = n => String(n).padStart(2, "0");
        return s >= 3600 ? Math.floor(s / 3600) + ":" + two(Math.floor(s / 60) % 60) + ":" + two(s % 60)
                         : two(Math.floor(s / 60)) + ":" + two(s % 60);
    }
    // The milliseconds until the shown second changes, a few ms late so it lands past the boundary.
    function arm() {
        if (!live || !running) {
            step.stop();
            return;
        }
        const s = shown.seconds;
        const left = shown.down ? s - (Math.ceil(s - 1e-6) - 1) : Math.floor(s + 1e-6) + 1 - s;
        step.interval = Math.max(20, Math.round(left * 1000) + 4);
        step.restart();
    }
    onRunningChanged: arm()
    Timer {
        id: step
        repeat: false
        onTriggered: { root.now = Date.now(); root.arm(); }
    }

    // The readout's detail: what else is running or held, besides the one shown.
    readonly property var others: {
        if (!timers.available || shown.kind === "done")
            return [];
        const out = [];
        if (shown.kind !== "pomodoro" && (timers.pomodoroRunning || value("pomodoro") > 0))
            out.push((timers.pomodoroBreak ? "BREAK " : "FOCUS ") + clock(Math.ceil(Math.max(0, timers.pomodoroLapDuration - value("pomodoro")) - 1e-6)));
        if (shown.kind !== "countdown" && (timers.countdownRunning || value("countdown") > 0) && timers.countdownDuration > 0)
            out.push("COUNTDOWN " + clock(Math.ceil(Math.max(0, timers.countdownDuration - value("countdown")) - 1e-6)));
        if (shown.kind !== "stopwatch" && (timers.stopwatchRunning || value("stopwatch") > 0))
            out.push("STOPWATCH " + clock(Math.floor(value("stopwatch") + 1e-6)));
        return out;
    }
    figure: !timers.available ? "–" : alarm ? "DONE" : clock(whole)
    figureWeight: running ? Font.Black : Font.Light
    note: shown.note
    detail: shown.kind === "idle" ? "FOCUS " + clock(timers.focusTime) + " · BREAK " + clock(timers.breakTime) : others.join(" · ")

    Accessible.role: Accessible.StaticText
    Accessible.name: shown.kind === "done" ? "Timer done" : shown.note.toLowerCase() + " " + clock(whole)
}
