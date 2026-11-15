import QtQuick
import QtQuick.Layouts
import qs.view.rooms
import qs.view.cues
import qs.view.ui
import "TimersSkyLayout.js" as Sky

// Confluence Timers (owner's pick "B + C", "majestic"): the room is a sky (TimersSky). You stand on a planet; over a
// stretch a black hole crosses it, rise to set, and the time still to go falls into it while one pulsing light marks
// now. Each clock is the same sky read its own way: Focus, a stretch per day and rest as night; Countdown, one
// stretch; Stopwatch, the light falls in once a minute; Session, the long deep fall. The numerals stand large in
// the sky; the plan, lengths, laps or presets and the controls lie on the planet's dark face. State and actions are
// the room's controller's (TimersSession), shared with Angular.
Item {
    id: root
    required property TimersSession controller
    readonly property var timers: controller.timers
    readonly property string kind: controller.kind

    component Caption: FluidText { color: FluidTokens.secondary; font.pixelSize: FluidTokens.caption; font.capitalization: Font.AllUppercase; font.letterSpacing: 2 }

    // "HH:mm" a number of seconds from now; reading Clock.minuteStr keeps it current without a timer of its own.
    function endsAt(seconds: real): string {
        const minute = Clock.minuteStr;  // dependency only
        return Qt.formatTime(new Date(Date.now() + seconds * 1000), "HH:mm");
    }

    // Focus: every cycle's focus and rest, where we are in it and how far through the current stretch.
    readonly property var plan: {
        const cycles = Math.max(1, controller.cycles), focus = Math.max(1, timers.focusTime), rest = Math.max(0, timers.breakTime);
        const out = [];
        for (let i = 0; i < cycles; i++) {
            out.push({ kind: "focus", cycle: i, seconds: focus });
            if (rest > 0) out.push({ kind: "rest", cycle: i, seconds: rest });
        }
        return out;
    }
    readonly property bool planStarted: timers.pomodoroRunning || timers.value("pomodoro") > 0
    readonly property int planIndex: planStarted ? 2 * timers.pomodoroCycle + (timers.pomodoroBreak ? 1 : 0) : 0
    readonly property real planTotal: plan.reduce((sum, p) => sum + p.seconds, 0)
    readonly property real stretchDone: timers.pomodoroLapDuration > 0 ? 1 - timers.pomodoroSecondsLeft / timers.pomodoroLapDuration : 0

    // How the sky reads for the clock showing: lit (a stretch under way) and progress through it.
    readonly property bool lit: {
        switch (kind) {
        case "pomodoro": return planStarted && !timers.pomodoroBreak;
        case "countdown": return timers.countdownDuration > 0 && !timers.countdownDone;
        case "stopwatch": return timers.stopwatchRunning || timers.stopwatchSeconds > 0;
        case "session": return controller.active !== null;
        }
        return false;
    }
    readonly property real progress: {
        switch (kind) {
        case "pomodoro": return Math.max(0, Math.min(1, stretchDone));
        case "countdown": return timers.countdownDuration > 0 ? Math.max(0, Math.min(1, 1 - timers.countdownSecondsLeft / timers.countdownDuration)) : 0;
        case "stopwatch": return (timers.stopwatchSeconds % 60) / 60;
        case "session": return controller.active ? Math.max(0, Math.min(1, 1 - controller.sessionLeft / Math.max(1, controller.active.seconds))) : 0;
        }
        return 0;
    }
    readonly property string phaseLine: {
        switch (kind) {
        case "pomodoro": return (planStarted && timers.pomodoroBreak ? "Rest · cycle " : "Focus · cycle ") + (timers.pomodoroCycle + 1) + " of " + controller.cycles;
        case "countdown": return timers.countdownDuration > 0 ? (timers.countdownDone ? "Countdown · done" : "Countdown · ends " + endsAt(timers.countdownSecondsLeft)) : "Countdown";
        case "stopwatch": return "Stopwatch · " + (timers.stopwatchLaps.length ? timers.stopwatchLaps.length + (timers.stopwatchLaps.length === 1 ? " lap" : " laps") : "no laps");
        case "session": return controller.active ? String(controller.active.preset) + " session · Silent holds" : controller.debrief ? "Last session · " + controller.debrief.preset : "Session";
        }
        return "";
    }
    readonly property string sentence: {
        switch (kind) {
        case "pomodoro":
            if (!planStarted) return "Start, and the first stretch rises.";
            return timers.pomodoroBreak ? "The disc is dark. Rest under the stars until the next stretch rises."
                                        : "The light is now, falling in. When the bright matter is gone, the hole sets.";
        case "countdown":
            if (timers.countdownDone) return "Fallen in. The countdown is done.";
            return timers.countdownDuration > 0 ? "The bright matter is the time still to go." : "Pick a length, and the hole rises.";
        case "stopwatch":
            return root.lit ? "No deadline. The light falls in once a minute and rises again at the rim." : "Start, and the light begins its fall.";
        case "session":
            if (controller.active) return "Until " + endsAt(controller.sessionLeft) + ". Notifications wait at the rim.";
            if (controller.debrief) return controller.debrief.completed ? "The last session fell in completely." : "The last session ended early, " + Math.round(100 * controller.debrief.seconds / Math.max(1, controller.debrief.planned)) + "% of the way in.";
            return "Pick a length. The longest fall; Silent holds while it runs.";
        }
        return "";
    }

    TimersSky {
        objectName: "timers.sky"
        anchors.fill: parent
        progress: root.progress
        arc: root.kind === "stopwatch" ? 0.5 : root.progress   // no deadline: the hole stands at the top
        lit: root.lit
        running: root.controller.running
    }

    // Status and the clock picker along the top, as Media sets them.
    RowLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: FluidTokens.sectionGap
        FluidText {
            objectName: "timers.status"
            text: root.kind === "session" ? (root.controller.active ? "In session" : "No session")
                : root.controller.completed ? "Done" : !root.timers.available ? "Offline" : root.controller.running ? "Running" : "Held"
            color: FluidTokens.secondary
        }
        Item { Layout.fillWidth: true }
        FluidChoice {
            objectName: "timers.modes"
            Layout.preferredWidth: Math.min(460, root.width * 0.5)
            label: "Clock"
            model: root.controller.modes.map(m => m.name)
            currentIndex: root.controller.modeIndex
            onActivated: index => root.controller.setKind(root.controller.modes[index].id)
        }
    }

    // The reading, large in the sky.
    ColumnLayout {
        anchors.left: parent.left
        anchors.leftMargin: FluidTokens.sectionGap * 2
        anchors.top: parent.top
        anchors.topMargin: FluidTokens.sectionGap * 3
        spacing: FluidTokens.unit
        Caption { objectName: "timers.phase"; text: root.phaseLine }
        FluidText {
            objectName: "timers.clock"
            text: root.controller.completed ? "Done"
                : root.kind === "session" && !root.controller.active && !root.controller.debrief ? "Ready"
                : root.controller.stamp(root.controller.seconds)
            font.pixelSize: Math.min(Sky.clockSize, root.height * 0.24) // scale: the numerals keep below the sky's middle
            font.weight: Font.ExtraLight
            font.letterSpacing: Sky.clockTracking
            font.features: ({ "tnum": 1 })
        }
        FluidText {
            objectName: "timers.sentence"
            Layout.preferredWidth: Sky.sentenceWidth
            text: root.sentence
            font.pixelSize: FluidTokens.heading
            font.weight: Font.Light
            color: FluidTokens.secondary
            wrapMode: Text.Wrap
        }
    }

    // On the planet's dark face: what this clock needs, then the controls.
    ColumnLayout {
        objectName: "timers.face"
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: FluidTokens.gap
        width: Math.min(parent.width - 2 * FluidTokens.sectionGap, 900)
        spacing: FluidTokens.gap

        // Focus: the plan, a stretch per day and a rest per night.
        Row {
            Layout.alignment: Qt.AlignHCenter
            visible: root.kind === "pomodoro"
            spacing: FluidTokens.unit * 1.5
            Repeater {
                model: root.kind === "pomodoro" ? root.plan : []
                Column {
                    id: stretch
                    required property var modelData
                    required property int index
                    readonly property real fill: !root.planStarted ? 0 : index < root.planIndex ? 1 : index === root.planIndex ? root.stretchDone : 0
                    spacing: FluidTokens.unit * 1.5
                    width: modelData.kind === "focus" ? 96 : 30
                    Rectangle {
                        width: parent.width
                        height: 3
                        radius: 2
                        color: Design.coldLine
                        Rectangle { width: parent.width * stretch.fill; height: parent.height; radius: 2
                                    color: stretch.modelData.kind === "focus" ? Design.coldStar : Design.coldInk }
                    }
                    Caption {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: stretch.modelData.kind === "focus" ? "Focus " + (stretch.modelData.cycle + 1) : "R"
                        color: stretch.index === root.planIndex && root.planStarted ? FluidTokens.ink : FluidTokens.secondary
                    }
                }
            }
        }
        // Countdown: lengths, each with the time it would end.
        Flow {
            Layout.alignment: Qt.AlignHCenter
            visible: root.kind === "countdown"
            spacing: FluidTokens.unit * 2
            Repeater {
                model: root.kind === "countdown" ? root.controller.countdownMinutes : []
                FluidButton {
                    required property int modelData
                    objectName: "timers.countdown." + modelData
                    text: modelData + " min · " + root.endsAt(modelData * 60)
                    enabled: root.timers.available
                    onClicked: root.controller.startCountdown(modelData)
                }
            }
        }
        // Stopwatch: the laps, oldest to newest along the face; the fastest in the accent.
        Row {
            Layout.alignment: Qt.AlignHCenter
            visible: root.kind === "stopwatch" && root.controller.splits.length > 0
            spacing: FluidTokens.sectionGap
            Repeater {
                model: root.kind === "stopwatch" ? root.controller.splits.slice().reverse() : []
                Column {
                    id: lap
                    required property var modelData
                    readonly property bool best: Math.abs(modelData.split - root.controller.fastest) < 0.005
                    objectName: "timers.lap." + modelData.number
                    spacing: FluidTokens.unit
                    Caption { text: "Lap " + lap.modelData.number + (lap.best ? " · fastest" : ""); color: lap.best ? FluidTokens.accent : FluidTokens.secondary }
                    FluidText { text: root.controller.splitStamp(lap.modelData.split); font.pixelSize: FluidTokens.heading; font.weight: Font.Light
                                font.features: ({ "tnum": 1 }); color: lap.best ? FluidTokens.accent : FluidTokens.ink }
                }
            }
        }
        // Session: the presets while none runs, each with the time it would end.
        Flow {
            Layout.alignment: Qt.AlignHCenter
            visible: root.kind === "session" && !root.controller.active
            spacing: FluidTokens.unit * 2
            Repeater {
                model: root.kind === "session" && !root.controller.active ? root.controller.presets : []
                FluidButton {
                    required property var modelData
                    objectName: "timers.preset." + modelData.name
                    text: String(modelData.name).charAt(0).toUpperCase() + String(modelData.name).slice(1) + " · " + root.controller.lengthLabel(modelData.seconds)
                        + " · " + root.endsAt(modelData.seconds)
                    enabled: root.timers.available
                    onClicked: root.controller.startSession(modelData.name)
                }
            }
        }
        // The controls, centred.
        Row {
            Layout.alignment: Qt.AlignHCenter
            spacing: FluidTokens.unit * 2
            FluidButton { objectName: "timers.reset"; visible: root.kind !== "session"; text: "Reset"; enabled: root.timers.available; onClicked: root.controller.reset() }
            FluidButton { objectName: "timers.toggle"; visible: root.kind !== "session"; text: root.controller.running ? "Pause" : "Start"; primary: true
                          enabled: root.controller.canToggle; onClicked: root.controller.toggle() }
            FluidButton { objectName: "timers.lap"; visible: root.kind === "stopwatch"; text: "Lap"; enabled: root.controller.running; onClicked: root.controller.lap() }
            FluidButton { objectName: "timers.addMinute"; visible: root.kind === "countdown"; text: "+1 min"; enabled: root.timers.available; onClicked: root.controller.addMinute() }
            FluidButton { objectName: "timers.endSession"; visible: root.kind === "session" && root.controller.active !== null; text: "End session"; onClicked: root.controller.endSession() }
            FluidButton { objectName: "timers.dismissDebrief"; visible: root.kind === "session" && !root.controller.active && !!root.controller.debrief
                          text: "Clear the last session"; onClicked: root.controller.dismissDebrief() }
        }
    }
}
