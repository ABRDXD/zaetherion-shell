import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import qs.view.rooms
import qs.view.cues
import qs.view.ui

// Confluence Timers. The interval is one revolution of an orbit: a large thin ring holds the clock, the lit arc is the
// time already passed and one small body rides its leading edge, now. Focus draws its whole plan on the ring (focus
// and rest arcs for every cycle), so the reading is "where am I in the set", not only "how long is left". Across a
// vertical rule, what this clock needs (lengths with the time each would end, the plan, laps, session presets and the
// streak); the other clocks wait quietly at the bottom edges. Status and the picker sit as in Media; the controls are
// centred under the ring. State and actions are the room's controller's (TimersSession), shared with Angular.
ColumnLayout {
    id: root
    required property TimersSession controller
    readonly property var timers: controller.timers
    readonly property bool compact: width < 860
    spacing: FluidTokens.gap

    component Rule: Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: FluidTokens.rule }
    component Caption: FluidText { color: FluidTokens.secondary; font.pixelSize: FluidTokens.caption }

    readonly property var names: ({ countdown: "Countdown", pomodoro: "Focus", stopwatch: "Stopwatch", session: "Session" })
    // "HH:mm" a number of seconds from now; reading Clock.minuteStr keeps it current without a timer of its own.
    function endsAt(seconds: real): string {
        const minute = Clock.minuteStr;  // dependency only
        return Qt.formatTime(new Date(Date.now() + seconds * 1000), "HH:mm");
    }

    // The Focus plan: every cycle's focus and rest as arcs of one revolution, and how far through the set we are.
    readonly property var plan: {
        const cycles = Math.max(1, controller.cycles), focus = Math.max(1, timers.focusTime), rest = Math.max(0, timers.breakTime);
        const out = [];
        for (let i = 0; i < cycles; i++) {
            out.push({ kind: "focus", cycle: i, seconds: focus });
            if (rest > 0) out.push({ kind: "rest", cycle: i, seconds: rest });
        }
        return out;
    }
    readonly property real planTotal: plan.reduce((sum, p) => sum + p.seconds, 0)
    readonly property bool planStarted: timers.pomodoroRunning || timers.value("pomodoro") > 0
    readonly property real planDone: {
        if (!planStarted) return 0;
        const focus = Math.max(1, timers.focusTime), rest = Math.max(0, timers.breakTime), cycle = timers.pomodoroCycle;
        const left = timers.pomodoroSecondsLeft;
        return cycle * (focus + rest) + (timers.pomodoroBreak ? focus + (rest - left) : focus - left);
    }
    // The ring's reading, 0–1: the plan for Focus, the minute for the stopwatch, the interval otherwise.
    readonly property real progress: controller.kind === "pomodoro" ? (planTotal > 0 ? planDone / planTotal : 0)
        : Math.max(0, Math.min(1, controller.fraction))
    // Only a change of clock sweeps the ring (one plain animation, the motion rule); the seconds tick straight on.
    property real shownProgress: 0
    Component.onCompleted: shownProgress = progress
    onProgressChanged: if (!sweep.running) shownProgress = progress
    NumberAnimation {
        id: sweep
        target: root
        property: "shownProgress"
        duration: Motion.scaled(420)
        easing.type: Easing.OutCubic
    }
    Connections {
        target: root.controller
        function onKindChanged() {
            if (!Motion.live(root)) { root.shownProgress = root.progress; return; }
            sweep.stop();
            sweep.from = root.shownProgress;
            sweep.to = root.progress;
            sweep.start();
        }
    }

    readonly property string status: {
        const c = controller;
        if (c.kind === "session") return c.active ? "In session" : c.debrief ? "Last session" : "No session";
        if (c.completed) return "Done";
        if (!timers.available) return "Offline";
        return c.running ? "Running" : "Held";
    }
    readonly property string modeLine: {
        const c = controller;
        switch (c.kind) {
        case "pomodoro": return (timers.pomodoroBreak ? "Rest" : "Focus") + " · cycle " + (timers.pomodoroCycle + 1) + " of " + c.cycles;
        case "stopwatch": return "No deadline";
        case "session": return c.active ? String(c.active.preset) : c.debrief ? String(c.debrief.preset) + (c.debrief.completed ? " · complete" : " · ended early") : "Pick a length";
        default: return c.running || timers.countdownDuration > 0 ? "Ends " + root.endsAt(timers.countdownSecondsLeft) : "Set a length";
        }
    }
    // What another clock reads now, for the quiet edges.
    function glance(id: string): string {
        switch (id) {
        case "countdown": return timers.countdownDuration > 0 ? (timers.countdownDone ? "Done" : controller.stamp(timers.countdownSecondsLeft) + (timers.countdownRunning ? "" : " held")) : "Not set";
        case "pomodoro": return planStarted ? controller.stamp(timers.pomodoroSecondsLeft) + (timers.pomodoroRunning ? "" : " held") : "Idle";
        case "stopwatch": return timers.stopwatchRunning || timers.stopwatchSeconds > 0 ? controller.stamp(timers.stopwatchSeconds) + (timers.stopwatchRunning ? "" : " held") : "Idle";
        case "session": return controller.active ? controller.stamp(controller.sessionLeft) + " left" : "None";
        }
        return "";
    }
    readonly property var others: controller.modes.filter(m => m.id !== controller.kind)

    // Status and the picker, as Media sets "Paused" against its player.
    RowLayout {
        Layout.fillWidth: true
        FluidText { objectName: "timers.status"; text: root.status; color: FluidTokens.secondary }
        Item { Layout.fillWidth: true }
        FluidChoice {
            objectName: "timers.modes"
            Layout.preferredWidth: Math.min(460, root.width * 0.6)
            label: "Clock"
            model: root.controller.modes.map(m => m.name)
            currentIndex: root.controller.modeIndex
            onActivated: index => root.controller.setKind(root.controller.modes[index].id)
        }
    }

    RowLayout {
        objectName: "timers.main"
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: 0
        spacing: FluidTokens.sectionGap

        // The orbit and the clock.
        Item {
            id: dial
            objectName: "timers.dial"
            Layout.fillHeight: true
            Layout.preferredWidth: side
            Layout.minimumWidth: 0
            readonly property real side: Math.min(height, root.width * (root.compact ? 0.5 : 0.44))
            readonly property real r: Math.max(0, Math.min(width, height) / 2 - FluidTokens.gap)
            readonly property real cx: width / 2
            readonly property real cy: height / 2
            readonly property real lead: -90 + 360 * root.shownProgress   // the leading edge, degrees from 3 o'clock

            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                // The full revolution, quiet.
                ShapePath {
                    strokeColor: FluidTokens.rule
                    strokeWidth: 1.5
                    fillColor: "transparent"
                    PathAngleArc { centerX: dial.cx; centerY: dial.cy; radiusX: dial.r; radiusY: dial.r; startAngle: -90; sweepAngle: 360 }
                }
                // What has passed, in the accent (every clock but Focus, which draws its plan below).
                ShapePath {
                    strokeColor: root.controller.kind === "pomodoro" ? "transparent" : FluidTokens.accent
                    strokeWidth: 3
                    capStyle: ShapePath.RoundCap
                    fillColor: "transparent"
                    PathAngleArc { centerX: dial.cx; centerY: dial.cy; radiusX: dial.r; radiusY: dial.r; startAngle: -90; sweepAngle: 360 * root.shownProgress }
                }
            }
            // Focus: the plan as arcs with a small gap between each; passed arcs in the accent, rests thinner.
            Repeater {
                model: root.controller.kind === "pomodoro" ? root.plan : []
                Shape {
                    id: stretchArc
                    required property var modelData
                    required property int index
                    readonly property real start: root.plan.slice(0, index).reduce((s, p) => s + p.seconds, 0) / Math.max(1, root.planTotal)
                    readonly property real span: modelData.seconds / Math.max(1, root.planTotal)
                    readonly property real gap: 2.5 / 360
                    readonly property real lit: Math.max(0, Math.min(1, (root.shownProgress - start) / span))
                    readonly property real weight: modelData.kind === "rest" ? 1.5 : 3
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        strokeColor: Qt.alpha(FluidTokens.ink, stretchArc.modelData.kind === "rest" ? 0.25 : 0.45)
                        strokeWidth: stretchArc.weight
                        fillColor: "transparent"
                        PathAngleArc { centerX: dial.cx; centerY: dial.cy; radiusX: dial.r; radiusY: dial.r
                                       startAngle: -90 + 360 * (stretchArc.start + stretchArc.gap); sweepAngle: 360 * Math.max(0, stretchArc.span - 2 * stretchArc.gap) }
                    }
                    ShapePath {
                        strokeColor: FluidTokens.accent
                        strokeWidth: stretchArc.weight
                        fillColor: "transparent"
                        PathAngleArc { centerX: dial.cx; centerY: dial.cy; radiusX: dial.r; radiusY: dial.r
                                       startAngle: -90 + 360 * (stretchArc.start + stretchArc.gap); sweepAngle: 360 * Math.max(0, stretchArc.span - 2 * stretchArc.gap) * stretchArc.lit }
                    }
                }
            }
            // Now: one small body at the leading edge, only while there is something to measure.
            Rectangle {
                objectName: "timers.now"
                readonly property real a: dial.lead * Math.PI / 180
                visible: root.controller.running || root.shownProgress > 0
                width: FluidTokens.unit * 3
                height: width
                radius: width / 2
                x: dial.cx + dial.r * Math.cos(a) - width / 2
                y: dial.cy + dial.r * Math.sin(a) - height / 2
                color: FluidTokens.ink
                border.width: 2
                border.color: FluidTokens.base
            }
            ColumnLayout {
                anchors.centerIn: parent
                width: dial.r * 1.6
                spacing: FluidTokens.unit
                Caption { Layout.alignment: Qt.AlignHCenter; text: root.names[root.controller.kind].toUpperCase() }
                FluidText {
                    objectName: "timers.clock"
                    Layout.alignment: Qt.AlignHCenter
                    Layout.maximumWidth: parent.width
                    text: root.controller.completed ? "Done"
                        : root.controller.kind === "session" && !root.controller.active && !root.controller.debrief ? "Ready"
                        : root.controller.stamp(root.controller.seconds)
                    font.pixelSize: Math.min(FluidTokens.clock, dial.r * 0.62) // scale: the numerals fit inside the ring
                    font.weight: Font.Light
                    font.features: ({ "tnum": 1 })
                    font.letterSpacing: -2
                    color: root.controller.completed ? FluidTokens.accent : FluidTokens.ink
                }
                FluidText {
                    objectName: "timers.modeLine"
                    Layout.alignment: Qt.AlignHCenter
                    Layout.maximumWidth: parent.width
                    text: root.modeLine
                    color: FluidTokens.secondary
                    elide: Text.ElideRight
                }
            }
        }

        Rectangle { Layout.fillHeight: true; implicitWidth: 1; color: FluidTokens.rule }

        // What this clock needs.
        ColumnLayout {
            objectName: "timers.details"
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumWidth: 0
            spacing: FluidTokens.unit * 2

            // Countdown: lengths, each with the time it would end.
            Caption { visible: root.controller.kind === "countdown"; text: "START A COUNTDOWN" }
            Repeater {
                model: root.controller.kind === "countdown" ? root.controller.countdownMinutes : []
                ColumnLayout {
                    required property int modelData
                    Layout.fillWidth: true
                    spacing: 0
                    FluidActionRow {
                        objectName: "timers.countdown." + modelData
                        Layout.fillWidth: true
                        text: modelData + " minutes"
                        detail: "until " + root.endsAt(modelData * 60)
                        enabled: root.timers.available
                        onClicked: root.controller.startCountdown(modelData)
                    }
                    Rule {}
                }
            }

            // Focus: the plan, the current stretch marked; when the whole set ends.
            Caption {
                visible: root.controller.kind === "pomodoro"
                text: "THE PLAN · " + Math.round(root.planTotal / 60) + " MIN"
                    + (root.timers.pomodoroRunning ? " · DONE BY " + root.endsAt(root.planTotal - root.planDone) : "")
            }
            Repeater {
                model: root.controller.kind === "pomodoro" ? root.plan : []
                RowLayout {
                    id: stretch
                    required property var modelData
                    readonly property bool now: root.planStarted && modelData.cycle === root.timers.pomodoroCycle
                        && (modelData.kind === "rest") === root.timers.pomodoroBreak
                    Layout.fillWidth: true
                    Layout.preferredHeight: FluidTokens.controlHeight * 0.8
                    Rectangle {
                        implicitWidth: FluidTokens.unit * 2
                        implicitHeight: implicitWidth
                        radius: width / 2
                        color: stretch.now ? FluidTokens.accent : "transparent"
                        border.width: 1
                        border.color: stretch.now ? FluidTokens.accent : FluidTokens.rule
                    }
                    FluidText { Layout.fillWidth: true; text: (stretch.modelData.kind === "focus" ? "Focus " : "Rest ") + (stretch.modelData.cycle + 1)
                                color: stretch.now ? FluidTokens.ink : FluidTokens.secondary }
                    FluidText { text: Math.round(stretch.modelData.seconds / 60) + " min"; color: FluidTokens.secondary; font.features: ({ "tnum": 1 }) }
                }
            }

            // Stopwatch: the laps, newest first; the fastest in the accent.
            Caption { visible: root.controller.kind === "stopwatch"; text: root.timers.stopwatchLaps.length ? "LAPS · " + root.timers.stopwatchLaps.length : "LAPS" }
            Repeater {
                model: root.controller.kind === "stopwatch" ? root.controller.splits : []
                ColumnLayout {
                    id: lap
                    required property var modelData
                    readonly property bool best: Math.abs(modelData.split - root.controller.fastest) < 0.005
                    objectName: "timers.lap." + modelData.number
                    Layout.fillWidth: true
                    spacing: 0
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: FluidTokens.controlHeight
                        FluidText { Layout.fillWidth: true; text: "Lap " + lap.modelData.number + (lap.best ? " · fastest" : ""); color: lap.best ? FluidTokens.accent : FluidTokens.ink }
                        FluidText { text: root.controller.splitStamp(lap.modelData.split); font.pixelSize: FluidTokens.heading; font.weight: Font.Light
                                    font.features: ({ "tnum": 1 }); color: lap.best ? FluidTokens.accent : FluidTokens.ink }
                    }
                    Rule {}
                }
            }
            FluidText {
                visible: root.controller.kind === "stopwatch" && root.controller.splits.length === 0
                Layout.fillWidth: true
                text: "No laps yet. Just the one long one."
                font.pixelSize: FluidTokens.heading
                color: FluidTokens.secondary
                wrapMode: Text.Wrap
            }

            // Session: the presets, each with the time it would end; then the streak as fourteen quiet days.
            Caption { visible: root.controller.kind === "session" && !root.controller.active; text: "BEGIN A SESSION · SILENT HOLDS WHILE IT RUNS" }
            Repeater {
                model: root.controller.kind === "session" && !root.controller.active ? root.controller.presets : []
                ColumnLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: 0
                    FluidActionRow {
                        objectName: "timers.preset." + modelData.name
                        Layout.fillWidth: true
                        text: String(modelData.name).charAt(0).toUpperCase() + String(modelData.name).slice(1) + " · " + root.controller.lengthLabel(modelData.seconds)
                        detail: "until " + root.endsAt(modelData.seconds)
                        enabled: root.timers.available
                        onClicked: root.controller.startSession(modelData.name)
                    }
                    Rule {}
                }
            }
            FluidText {
                visible: root.controller.kind === "session" && !!root.controller.active
                Layout.fillWidth: true
                text: "Until " + root.endsAt(root.controller.sessionLeft) + ". Notifications wait; the desk stays Silent."
                font.pixelSize: FluidTokens.heading
                wrapMode: Text.Wrap
            }
            ColumnLayout {
                objectName: "timers.streak"
                visible: root.controller.kind === "session" && (root.controller.streak?.minutes?.length ?? 0) > 0
                Layout.fillWidth: true
                Layout.topMargin: FluidTokens.gap
                spacing: FluidTokens.unit * 2
                Caption {
                    text: (root.controller.streak?.current ?? 0) > 0
                        ? root.controller.streak.current + (root.controller.streak.current === 1 ? " DAY" : " DAYS") + " IN A ROW · BEST " + (root.controller.streak.best ?? 0)
                        : "THE LAST TWO WEEKS"
                }
                Row {
                    id: days
                    readonly property var minutes: root.controller.streak?.minutes ?? []
                    readonly property real most: Math.max(1, ...minutes)
                    Layout.fillWidth: true
                    Layout.preferredHeight: FluidTokens.controlHeight * 1.4
                    spacing: FluidTokens.unit
                    Repeater {
                        model: days.minutes
                        Rectangle {
                            required property real modelData
                            required property int index
                            width: (days.width - (days.minutes.length - 1) * days.spacing) / Math.max(1, days.minutes.length)
                            height: modelData > 0 ? Math.max(FluidTokens.unit, days.height * modelData / days.most) : 1
                            y: days.height - height
                            radius: Math.min(width / 2, FluidTokens.unit)
                            color: index === days.minutes.length - 1 ? FluidTokens.accent : modelData > 0 ? Qt.alpha(FluidTokens.ink, 0.45) : FluidTokens.rule
                        }
                    }
                }
            }
            FluidActionRow {
                objectName: "timers.dismissDebrief"
                Layout.fillWidth: true
                visible: root.controller.kind === "session" && !root.controller.active && !!root.controller.debrief
                text: "Clear the last session"
                detail: "→"
                onClicked: root.controller.dismissDebrief()
            }
            Item { Layout.fillHeight: true; Layout.minimumHeight: 0 }
        }
    }

    Rule {}
    // The controls, centred under the ring as Media centres its transport; the other clocks wait at the edges.
    RowLayout {
        Layout.fillWidth: true
        spacing: FluidTokens.unit * 2
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            spacing: FluidTokens.gap
            Repeater {
                model: root.others.slice(0, 2)
                FluidActionRow {
                    required property var modelData
                    objectName: "timers.glance." + modelData.id
                    Layout.fillWidth: true
                    Layout.maximumWidth: 220
                    text: root.names[modelData.id]
                    detail: root.glance(modelData.id)
                    onClicked: root.controller.setKind(modelData.id)
                }
            }
        }
        FluidButton { objectName: "timers.reset"; visible: root.controller.kind !== "session"; text: "Reset"; enabled: root.timers.available; onClicked: root.controller.reset() }
        FluidButton { objectName: "timers.toggle"; visible: root.controller.kind !== "session"; text: root.controller.running ? "Pause" : "Start"; primary: true; enabled: root.controller.canToggle; onClicked: root.controller.toggle() }
        FluidButton { objectName: "timers.lap"; visible: root.controller.kind === "stopwatch"; text: "Lap"; enabled: root.controller.running; onClicked: root.controller.lap() }
        FluidButton { objectName: "timers.addMinute"; visible: root.controller.kind === "countdown"; text: "+1 min"; enabled: root.timers.available; onClicked: root.controller.addMinute() }
        FluidButton { objectName: "timers.endSession"; visible: root.controller.kind === "session" && root.controller.active !== null; text: "End session"; onClicked: root.controller.endSession() }
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            Item { Layout.fillWidth: true }
            FluidActionRow {
                readonly property var last: root.others[2] ?? null
                objectName: "timers.glance." + (last?.id ?? "")
                Layout.fillWidth: true
                Layout.maximumWidth: 220
                text: last ? root.names[last.id] : ""
                detail: last ? root.glance(last.id) : ""
                onClicked: if (last) root.controller.setKind(last.id)
            }
        }
    }
}
