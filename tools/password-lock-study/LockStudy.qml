pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
import "../../view/lock" as Lock

Window {
    id: win
    width: 1280
    height: 720
    visible: true
    readonly property var args: Qt.application.arguments
    function argument(key, fallback) {
        const i = args.indexOf(key)
        return i >= 0 ? args[i + 1] : fallback
    }
    readonly property bool fluid: args.includes("--fluid")
    readonly property bool reduced: args.includes("--reduced")
    // Milliseconds from fixture rejection. Negative time shows password entry.
    property int attempts: Number(argument("--attempt", "1"))
    property real holdProgress: Number(argument("--hold", "0"))
    property real elapsed: Number(argument("--at", "-1"))
    Item {
        id: sheet
        anchors.fill: parent
        focus: true
        Keys.onReturnPressed: {
            if (win.elapsed >= 0) win.attempts++
            win.elapsed = 0; replay.restart()
        }
        Keys.onEscapePressed: { replay.stop(); win.elapsed = -1 }
        Item {
            width: 1280; height: 720
            anchors.centerIn: parent
            scale: Math.min(sheet.width / width, sheet.height / height)
            Sky { anchors.fill: parent; fluid: win.fluid }
        }
        Lock.PasswordLockFace {
            anchors.fill: parent
            fluid: win.fluid
            timeText: "06:42"
            dateText: "Tuesday, 24 November 2026"
            maskLength: win.elapsed < 0 ? 6 : 0
            attempts: win.attempts
            reducedMotion: win.reduced
            rejectionMs: win.elapsed
            mediaAvailable: true
            trackTitle: "Low Moon"
            artist: "Vesper Field"
            playing: true
            batteryFraction: 0.76
            holdProgress: win.holdProgress
            onPowerHoldStarted: fill.restart()
            onPowerHoldEnded: { fill.stop(); win.holdProgress = 0 }
        }
    }
    NumberAnimation { id: fill; target: win; property: "holdProgress"; from: 0; to: 1; duration: 1000 }
    NumberAnimation { id: replay; target: win; property: "elapsed"; from: 0; to: 400; duration: 400 }
    Timer {
        running: win.args.includes("--out"); interval: 200
        onTriggered: sheet.grabToImage(image => Qt.exit(image.saveToFile(win.argument("--out", "")) ? 0 : 1))
    }
}
