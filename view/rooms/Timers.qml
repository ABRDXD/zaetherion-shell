import qs.core.client
import qs.view.contract
import qs.view.shell
import qs.view.ui
import qs.view.cues
import qs.view.strata
import QtQuick
import QtQuick.Layouts
import "TemporalMath.js" as Field

// Three clocks share one temporal field. All data and controls stay on undeformed solid planes.
Item {
    id: root
    required property HostAdapter host
    required property ShellContext shell
    required property CoreClient core
    readonly property CoreTimers timers: core.timers
    readonly property string kind: ViewState.timerKind
    // The session (M11): the running one, the last one's debrief, the streak and the presets, from the core.
    readonly property var session: core.sessionData?.active ?? null
    readonly property var debrief: core.sessionData?.last ?? null
    readonly property var streak: core.sessionData?.streak ?? null
    readonly property var presets: core.sessionData?.presets ?? []
    property real sessionNow: Date.now()
    Timer {
        interval: 1000
        repeat: true
        triggeredOnStart: true
        running: root.visible && root.session !== null
        onTriggered: root.sessionNow = Date.now()
    }
    readonly property real sessionLeft: session ? Math.max(0, (session.until - sessionNow) / 1000) : 0
    function lengthLabel(seconds) {
        return seconds % 3600 === 0 ? (seconds / 3600) + " h" : Math.round(seconds / 60) + " min";
    }
    readonly property bool narrow: width < 730
    readonly property bool running: kind === "session" ? session !== null : kind === "pomodoro" ? timers.pomodoroRunning : kind === "stopwatch"
                                                          ? timers.stopwatchRunning : timers.countdownRunning
    readonly property real seconds: kind === "session" ? (session ? sessionLeft : debrief?.seconds ?? 0) : kind === "pomodoro" ? timers.pomodoroSecondsLeft : kind === "stopwatch"
                                                          ? timers.stopwatchSeconds : timers.countdownSecondsLeft
    readonly property real duration: kind === "session" ? (session?.seconds ?? debrief?.planned ?? 0) : kind === "pomodoro" ? timers.pomodoroLapDuration : kind === "stopwatch"
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
    Binding { target: root.timers; property: "ticking"; value: root.visible }
    Binding { target: root.timers; property: "tickInterval"; value: 1000 }
    readonly property var sources: {
        const a = [];
        if (timers.pomodoroRunning || timers.value("pomodoro") > 0 || timers.pomodoroDone)
            a.push({kind:"pomodoro",x:.16,y:.73,seconds:Math.ceil(timers.pomodoroSecondsLeft),duration:timers.pomodoroLapDuration,deadline:true,running:timers.pomodoroRunning,done:!!timers.pomodoroDone});
        if (timers.countdownDuration > 0)
            a.push({kind:"countdown",x:.72,y:.24,seconds:Math.ceil(timers.countdownSecondsLeft),duration:timers.countdownDuration,deadline:true,running:timers.countdownRunning,done:timers.countdownDone});
        if (timers.stopwatchRunning || timers.stopwatchSeconds > 0)
            a.push({kind:"stopwatch",x:.80,y:.79,seconds:Math.floor(timers.stopwatchSeconds),duration:0,deadline:false,running:timers.stopwatchRunning,done:false});
        if (session)
            a.push({kind:"session",x:.46,y:.52,seconds:Math.ceil(sessionLeft),duration:session.seconds,deadline:true,running:true,done:false});
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
    readonly property bool fieldLoaded: fieldLayer.item !== null
    readonly property int staticPaints: contours.painted

    FText {
        id: title; text: "TEMPORAL FIELD"; headline: true; font.pixelSize: Design.headline
        font.weight: Font.Black; font.letterSpacing: -2
    }
    FText {
        anchors.right: parent.right; anchors.bottom: title.bottom; anchors.bottomMargin: 8
        text: "03 CLOCKS / ONE FIELD"; technical: true; color: Design.muted; visible: !root.narrow
    }
    RowLayout {
        id: tabs; anchors.top: title.bottom; anchors.topMargin: 10; width: parent.width; spacing: 3
        Repeater {
            model: root.modes
            SheetTab {
                required property var modelData
                label: modelData.name; selected: root.kind === modelData.id
                onClicked: ViewState.timerKind = modelData.id
            }
        }
        Hairline { Layout.fillWidth: true; Layout.leftMargin: 14; Layout.rightMargin: 14 }
        FText { text: root.timers.anyRunning ? "TIME IS MOVING" : "FIELD HELD"; technical: true; color: Design.muted }
    }
    Item {
        id: field
        anchors.top: tabs.bottom; anchors.topMargin: 16
        anchors.bottom: legend.top; anchors.bottomMargin: 8
        width: parent.width; clip: true
        // The entire field gets an opaque base; its annotations then each get their own backing plane.
        Plane { anchors.fill: parent; role: "paper" }
        TemporalContours {
            id: contours; anchors.fill: parent
            sources: root.sources; remainingFraction: root.remainingFraction
            opacity: fieldLayer.item ? 1 - Motion.drive : 1
        }
        Stratum {
            id: fieldLayer; name: "temporal-field"; scope: root; wanted: root.sources.length > 0
            anchors.fill: parent
            sourceComponent: Component {
                TemporalField {
                    sources: root.sources; remainingFraction: root.remainingFraction
                    flowing: root.timers.anyRunning; eventKey: root.eventKey; completionKey: root.completionKey
                }
            }
        }
        // One hero, in present time. Neither the digits nor their plane enters a shader.
        Item {
            id: readout
            x: 18; y: field.height * .16; width: Math.min(field.width * .48,440); height: Math.min(180,field.height*.47)
            Plane { id: heroPlane; anchors.fill: parent; role: "paper"; backing: true; slant: 2 }
            FText {
                x: 14; y: 12; text: root.kind === "session" ? (root.session ? String(root.session.preset).toUpperCase() + " / SESSION · SILENT HELD"
                                                               : root.debrief ? "LAST / " + String(root.debrief.preset).toUpperCase() : "NO SESSION / PICK A LENGTH")
                    : root.kind === "pomodoro" ? (root.timers.pomodoroBreak ? "REST" : "FOCUS") + " / CYCLE " + (root.timers.pomodoroCycle+1)
                    : root.kind === "stopwatch" ? "ELAPSED / NO DEADLINE" : "REMAINING / COUNTDOWN"
                technical: true; color: heroPlane.textColor
            }
            FText {
                objectName: "temporal-clock"
                x: 10; y: 34; width: parent.width-34
                fontSizeMode: Text.HorizontalFit; minimumPixelSize: Design.readout; elide: Text.ElideNone
                text: root.completed ? "DONE" : root.stamp(root.seconds)
                headline: true; font.weight: Font.Black
                font.pixelSize: Math.min(Design.display * 1.35,readout.width/3.2,readout.height*.65) // scale: primary clock fits the undeformed present plane
                font.letterSpacing: -4; color: root.completed ? Design.warm : heroPlane.textColor
            }
            FText {
                x: 14; anchors.bottom: parent.bottom; anchors.bottomMargin: 10
                text: root.kind === "session" && !root.session && root.debrief
                      ? (root.debrief.completed ? "SESSION COMPLETE" : "ENDED EARLY / " + Math.round(100 * root.debrief.seconds / Math.max(1, root.debrief.planned)) + "% OF THE PLAN")
                      : root.completed ? "INTERVAL COMPLETE" : root.running ? "RUNNING" : "HELD"
                technical: true; color: Design.muted
            }
        }
        // Anchor labels are also the mode selectors. Their locations never shear.
        Repeater {
            model: root.sources
            TemporalAnchor {
                required property var modelData
                width: Math.min(164,field.width*.28)
                x: Math.max(8,Math.min(field.width-width-8,modelData.x*field.width-width*.5))
                y: Math.max(8,Math.min(field.height-height-8,modelData.y*field.height-height*.5))
                kind: modelData.kind; seconds: modelData.seconds; running: modelData.running; done: modelData.done
                selected: root.kind === kind
                onClicked: ViewState.timerKind = kind
            }
        }
        SessionDebrief {
            visible: root.kind === "session" && (root.debrief !== null || root.streak !== null)
            x: Math.max(readout.x + readout.width + 16, field.width - width - 18)
            y: readout.y
            width: Math.min(340, field.width - readout.width - 52)
            height: implicitHeight
            debrief: root.session ? null : root.debrief
            streak: root.streak
            onDismissed: root.core.request("session.dismiss", {})
        }
        Plane {
            x: 10; y: 8; width: fieldLabel.implicitWidth+20; height: 24; backing: true
            FText { id: fieldLabel; anchors.centerIn: parent; text: root.sources.length ? "ISOCHRONES / 60 S" : "NO ACTIVE SOURCES"; technical: true; color: Design.muted }
        }
        Plane {
            anchors.right: parent.right; anchors.rightMargin: 10; anchors.bottom: parent.bottom; anchors.bottomMargin: 8
            width: compressionLabel.implicitWidth+20; height: 24; backing: true
            FText { id: compressionLabel; anchors.centerIn: parent; text: "FUTURE / " + Math.round(Field.compression(root.remainingFraction)*100) + "%"; technical: true; color: Design.muted }
        }
    }
    RowLayout {
        id: legend; anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: controls.top; anchors.bottomMargin: 18; spacing: 16
        FText { text: root.collision >= 0 && root.collision < 60 ? "CONVERGENCE / " + Math.round(root.collision) + " S APART" : "TIME BENDS. THE CLOCK DOES NOT."; technical: true; color: root.collision >= 0 && root.collision < 60 ? Design.accent : Design.muted }
        Hairline { Layout.fillWidth: true }
        FText { text: root.timers.available ? "CORE / CONNECTED" : "CORE / OFFLINE"; technical: true; color: Design.faint; visible: !root.narrow }
    }
    // The mode's plate, then the controls.
    RowLayout {
        id: controls
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        spacing: 8
        Repeater {
            model: root.kind === "countdown" ? [5, 15, 25, 45] : []
            FButton {
                required property int modelData
                label: modelData + " min"
                enabled: root.timers.available
                onClicked: {
                    root.shell.engagedTimerKind = "countdown";
                    root.timers.startCountdown(modelData * 60);
                }
            }
        }
        // Session: the presets while none runs, then its end.
        Repeater {
            model: root.kind === "session" && !root.session ? root.presets : []
            FButton {
                required property var modelData
                label: modelData.name + " " + root.lengthLabel(modelData.seconds)
                enabled: root.timers.available
                onClicked: root.core.request("session.start", { preset: modelData.name })
            }
        }
        FButton {
            visible: root.kind === "countdown"
            label: "+1 min"
            enabled: root.timers.available
            onClicked: root.timers.addCountdown(60)
        }
        // Focus: the lengths, ruled like the data plate.
        Repeater {
            model: root.kind === "pomodoro" ? [["Focus", root.timers.focusTime], ["Rest", root.timers.breakTime],
                                               ["Cycles", root.cycles]] : []
            ColumnLayout {
                id: length
                required property var modelData
                Layout.preferredWidth: 96
                spacing: 2
                FText {
                    text: length.modelData[0]
                    technical: true
                    color: Design.muted
                }
                FText {
                    text: length.modelData[0] === "Cycles" ? String(length.modelData[1]).padStart(2, "0")
                        : Math.round(length.modelData[1] / 60) + " MIN"
                    headline: true
                    font.pixelSize: Design.readout
                    font.weight: Font.Light
                }
                Hairline { Layout.fillWidth: true; node: 3 }
            }
        }
        // Stopwatch: the last four splits, newest first; the fastest marked in signal.
        Repeater {
            model: root.kind === "stopwatch" ? root.splits : []
            ColumnLayout {
                id: split
                required property var modelData
                readonly property bool best: Math.abs(modelData.split - root.fastest) < 0.005
                Layout.preferredWidth: root.narrow ? 72 : 96
                spacing: 2
                Row {
                    spacing: 6
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 5
                        height: 5
                        color: split.best ? Design.accent : Design.line
                    }
                    FText {
                        text: "LAP " + String(split.modelData.number).padStart(2, "0")
                        technical: true
                        color: Design.muted
                    }
                }
                FText {
                    text: root.stamp(split.modelData.split) + "." + (Math.floor(split.modelData.split * 100) % 100).toString().padStart(2, "0")
                    headline: true
                    font.pixelSize: Design.readout
                    font.weight: Font.Light
                    color: split.best ? Design.accent : Design.ink
                }
                Hairline { Layout.fillWidth: true; node: 3 }
            }
        }
        FText {
            visible: root.kind === "stopwatch" && root.splits.length === 0
            text: "no laps. just the one long one."
            aside: true
            color: Design.faint
        }
        Item {
            Layout.fillWidth: true
        }
        FButton {
            visible: root.kind === "stopwatch"
            label: "Lap"
            symbol: "flag"
            enabled: root.running
            onClicked: root.timers.lap()
        }
        FButton {
            visible: root.kind === "session" && root.session !== null
            label: "End session"
            symbol: "stop"
            danger: true
            onClicked: root.core.request("session.end", {})
        }
        FButton {
            visible: root.kind !== "session"
            label: "Reset"
            symbol: "restart_alt"
            enabled: root.timers.available
            onClicked: root.timers.reset(root.kind)
        }
        FButton {
            visible: root.kind !== "session"
            label: root.running ? "Pause" : "Start"
            symbol: root.running ? "pause" : "play_arrow"
            primary: true
            enabled: root.timers.available && (root.kind !== "countdown" || root.timers.countdownDuration > 0)
            onClicked: {
                root.shell.engagedTimerKind = root.kind;
                root.shell.toggleActiveTimer();
            }
        }
    }
}
