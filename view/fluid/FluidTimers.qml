import QtQuick
import QtQuick.Layouts
import qs.view.rooms
import qs.view.ui

// Confluence Timers: one clock large and light on a continuous surface, its mode's details under it, and every clock
// at a glance in a quieter column (as Confluence Home sets the day beside the calendar). State and actions are the
// room's controller's (TimersSession), shared with Angular's temporal field.
GridLayout {
    id: root
    required property TimersSession controller
    readonly property bool compact: width < 740
    readonly property var timers: controller.timers
    columns: compact ? 1 : 2
    columnSpacing: FluidTokens.sectionGap
    rowSpacing: FluidTokens.sectionGap

    component Rule: Rectangle {
        Layout.fillWidth: true
        implicitHeight: 1
        color: FluidTokens.rule
    }
    component Caption: FluidText { color: FluidTokens.secondary; font.pixelSize: FluidTokens.caption }

    // Plain words for the clocks, in the surface's voice.
    readonly property var names: ({ countdown: "Countdown", pomodoro: "Focus", stopwatch: "Stopwatch", session: "Session" })
    readonly property string modeLine: {
        const c = controller;
        switch (c.kind) {
        case "pomodoro": return (timers.pomodoroBreak ? "Rest" : "Focus") + " · cycle " + (timers.pomodoroCycle + 1) + " of " + c.cycles;
        case "stopwatch": return "Stopwatch · no deadline";
        case "session": return c.active ? "Session · " + c.active.preset : c.debrief ? "Last session · " + c.debrief.preset : "Session";
        default: return "Countdown";
        }
    }
    readonly property string stateLine: {
        const c = controller;
        if (c.kind === "session" && !c.active && c.debrief)
            return c.debrief.completed ? "Completed as planned." : "Ended early, " + Math.round(100 * c.debrief.seconds / Math.max(1, c.debrief.planned)) + "% of the plan.";
        if (c.kind === "session" && !c.active) return "Pick a length to begin. Silent holds while it runs.";
        if (c.completed) return "Done.";
        return c.running ? "Running." : timers.available ? "Held." : "Timers return when the core reconnects.";
    }
    // Every clock at a glance: what it reads now and whether it moves.
    function glance(id: string): string {
        switch (id) {
        case "countdown": return timers.countdownDuration > 0 ? (timers.countdownDone ? "Done" : controller.stamp(timers.countdownSecondsLeft) + (timers.countdownRunning ? "" : " · held")) : "Not set";
        case "pomodoro": return timers.pomodoroRunning || timers.value("pomodoro") > 0 ? controller.stamp(timers.pomodoroSecondsLeft) + (timers.pomodoroRunning ? "" : " · held") : "Idle";
        case "stopwatch": return timers.stopwatchRunning || timers.stopwatchSeconds > 0 ? controller.stamp(timers.stopwatchSeconds) + (timers.stopwatchRunning ? "" : " · held") : "Idle";
        case "session": return controller.active ? controller.stamp(controller.sessionLeft) + " left" : "None";
        }
        return "";
    }

    ColumnLayout {
        objectName: "timers.main"
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumWidth: 0
        Layout.preferredWidth: root.width * 0.62
        spacing: FluidTokens.unit * 3

        FluidChoice {
            objectName: "timers.modes"
            Layout.fillWidth: true
            label: "Clock"
            model: root.controller.modes.map(m => m.name)
            currentIndex: root.controller.modeIndex
            onActivated: index => root.controller.setKind(root.controller.modes[index].id)
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: FluidTokens.unit
            Caption { text: root.modeLine.toUpperCase() }
            FluidText {
                objectName: "timers.clock"
                Layout.fillWidth: true
                // An idle Session has no time yet: it reads "Ready" rather than a meaningless 0:00.
                text: root.controller.completed ? "Done"
                    : root.controller.kind === "session" && !root.controller.active && !root.controller.debrief ? "Ready"
                    : root.controller.stamp(root.controller.seconds)
                font.pixelSize: FluidTokens.clock
                font.weight: Font.Light
                font.features: ({ "tnum": 1 })
                font.letterSpacing: -2
                color: root.controller.completed ? FluidTokens.accent : FluidTokens.ink
            }
            // How far through: a quiet line, the accent for the part that has passed.
            Rectangle {
                objectName: "timers.progress"
                Layout.fillWidth: true
                implicitHeight: 2
                color: FluidTokens.rule
                visible: root.controller.kind !== "stopwatch" && root.controller.duration > 0
                Rectangle { width: parent.width * Math.max(0, Math.min(1, root.controller.fraction)); height: parent.height; color: FluidTokens.accent }
            }
            Caption { Layout.fillWidth: true; text: root.stateLine; wrapMode: Text.Wrap }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: FluidTokens.unit * 2
            FluidButton {
                objectName: "timers.toggle"
                visible: root.controller.kind !== "session"
                text: root.controller.running ? "Pause" : "Start"
                primary: true
                enabled: root.controller.canToggle
                onClicked: root.controller.toggle()
            }
            FluidButton {
                objectName: "timers.lap"
                visible: root.controller.kind === "stopwatch"
                text: "Lap"
                enabled: root.controller.running
                onClicked: root.controller.lap()
            }
            FluidButton {
                objectName: "timers.addMinute"
                visible: root.controller.kind === "countdown"
                text: "+1 min"
                enabled: root.timers.available
                onClicked: root.controller.addMinute()
            }
            FluidButton {
                objectName: "timers.reset"
                visible: root.controller.kind !== "session"
                text: "Reset"
                enabled: root.timers.available
                onClicked: root.controller.reset()
            }
            FluidButton {
                objectName: "timers.endSession"
                visible: root.controller.kind === "session" && root.controller.active !== null
                text: "End session"
                onClicked: root.controller.endSession()
            }
            Item { Layout.fillWidth: true }
        }
        Rule {}

        // The mode's own details.
        ColumnLayout {
            objectName: "timers.details"
            Layout.fillWidth: true
            spacing: FluidTokens.unit

            // Countdown: quick lengths.
            Caption { visible: root.controller.kind === "countdown"; text: "START A COUNTDOWN" }
            Flow {
                Layout.fillWidth: true
                visible: root.controller.kind === "countdown"
                spacing: FluidTokens.unit * 2
                Repeater {
                    model: root.controller.kind === "countdown" ? root.controller.countdownMinutes : []
                    FluidButton {
                        required property int modelData
                        objectName: "timers.countdown." + modelData
                        text: modelData + " min"
                        enabled: root.timers.available
                        onClicked: root.controller.startCountdown(modelData)
                    }
                }
            }

            // Focus: the lengths it runs with.
            Caption { visible: root.controller.kind === "pomodoro"; text: "LENGTHS" }
            Repeater {
                model: root.controller.kind === "pomodoro" ? [["Focus", Math.round(root.timers.focusTime / 60) + " min"],
                                                              ["Rest", Math.round(root.timers.breakTime / 60) + " min"],
                                                              ["Cycles", String(root.controller.cycles)]] : []
                ColumnLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: FluidTokens.unit
                    RowLayout {
                        Layout.fillWidth: true
                        FluidText { Layout.fillWidth: true; text: modelData[0] }
                        FluidText { text: modelData[1]; color: FluidTokens.secondary; font.features: ({ "tnum": 1 }) }
                    }
                    Rule {}
                }
            }

            // Stopwatch: the last four laps, newest first; the fastest in the accent.
            Caption { visible: root.controller.kind === "stopwatch"; text: "LAPS" }
            Repeater {
                model: root.controller.kind === "stopwatch" ? root.controller.splits : []
                ColumnLayout {
                    id: lap
                    required property var modelData
                    readonly property bool best: Math.abs(modelData.split - root.controller.fastest) < 0.005
                    objectName: "timers.lap." + modelData.number
                    Layout.fillWidth: true
                    spacing: FluidTokens.unit
                    RowLayout {
                        Layout.fillWidth: true
                        FluidText { Layout.fillWidth: true; text: "Lap " + lap.modelData.number + (lap.best ? " · fastest" : "") }
                        FluidText {
                            text: root.controller.splitStamp(lap.modelData.split)
                            font.features: ({ "tnum": 1 })
                            color: lap.best ? FluidTokens.accent : FluidTokens.ink
                        }
                    }
                    Rule {}
                }
            }
            FluidText {
                visible: root.controller.kind === "stopwatch" && root.controller.splits.length === 0
                text: "No laps yet. Just the one long one."
                color: FluidTokens.secondary
            }

            // Session: the presets while none runs.
            Caption { visible: root.controller.kind === "session" && !root.controller.active; text: "BEGIN A SESSION" }
            Repeater {
                model: root.controller.kind === "session" && !root.controller.active ? root.controller.presets : []
                FluidActionRow {
                    required property var modelData
                    objectName: "timers.preset." + modelData.name
                    Layout.fillWidth: true
                    text: String(modelData.name).charAt(0).toUpperCase() + String(modelData.name).slice(1)
                    detail: root.controller.lengthLabel(modelData.seconds) + " · Start →"
                    enabled: root.timers.available
                    onClicked: root.controller.startSession(modelData.name)
                }
            }
        }
        Item { Layout.fillHeight: true; Layout.minimumHeight: FluidTokens.unit }
    }

    ColumnLayout {
        objectName: "timers.aside"
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumWidth: 0
        Layout.preferredWidth: root.width * 0.32
        spacing: FluidTokens.gap
        Caption { text: "ALL CLOCKS" }
        Repeater {
            model: root.controller.modes
            ColumnLayout {
                required property var modelData
                Layout.fillWidth: true
                spacing: 0
                FluidActionRow {
                    objectName: "timers.glance." + modelData.id
                    Layout.fillWidth: true
                    text: root.names[modelData.id]
                    detail: (root.controller.kind === modelData.id ? "Showing · " : "") + root.glance(modelData.id)
                    onClicked: root.controller.setKind(modelData.id)
                }
                Rule {}
            }
        }
        // The streak, when there is one: a quiet fact, not a scoreboard.
        Caption {
            Layout.fillWidth: true
            visible: (root.controller.streak?.current ?? 0) > 0
            text: root.controller.streak.current + (root.controller.streak.current === 1 ? " day" : " days") + " in a row with a session"
                + ((root.controller.streak.best ?? 0) > root.controller.streak.current ? " (best " + root.controller.streak.best + ")." : ".")
            wrapMode: Text.Wrap
        }
        FluidActionRow {
            objectName: "timers.dismissDebrief"
            Layout.fillWidth: true
            visible: root.controller.kind === "session" && !root.controller.active && !!root.controller.debrief
            text: "Clear the last session"
            detail: "→"
            onClicked: root.controller.dismissDebrief()
        }
        Item { Layout.fillHeight: true; Layout.minimumHeight: FluidTokens.unit }
        Caption {
            Layout.fillWidth: true
            text: root.timers.anyRunning ? "Time is moving." : "Every clock is still."
        }
    }
}
