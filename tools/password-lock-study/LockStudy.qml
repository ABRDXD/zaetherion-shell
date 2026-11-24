pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window

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
    readonly property bool failed: elapsed >= (reduced ? 0 : 320)
    readonly property color ink: fluid ? "#fbf2ff" : "#fff2dc"
    readonly property color accent: fluid ? "#e1c8fc" : "#ffbf6a"
    readonly property color alert: "#ffb9a4"
    readonly property int small: 13
    readonly property int body: 18
    readonly property int track: 21
    readonly property int dateSize: fluid ? 24 : 22
    readonly property int clockSize: fluid ? 115 : 127

    component Legend: Text {
        color: win.ink
        font.family: "DejaVu Sans Mono"
        font.pixelSize: win.small
        font.letterSpacing: 1.5
    }
    component Label: Text {
        color: win.ink
        font.family: "Inter"
        font.pixelSize: win.body
    }
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
            Canvas {
                anchors.fill: parent
                onPaint: {
                    const c = getContext("2d")
                    c.reset()
                    if (win.fluid) {
                        // Offset arcs read as the lit limb of the atmosphere.
                        const glow = c.createRadialGradient(640, 303, 45, 640, 303, 345)
                        glow.addColorStop(0, "rgba(33,29,54,0.72)")
                        glow.addColorStop(0.62, "rgba(33,29,54,0.48)")
                        glow.addColorStop(1, "rgba(33,29,54,0)")
                        c.fillStyle = glow; c.fillRect(190, 0, 900, 690)
                        c.strokeStyle = "rgba(231,213,250,0.56)"
                        c.beginPath(); c.ellipse(345, 153, 590, 331); c.stroke()
                        c.strokeStyle = "rgba(231,213,250,0.20)"
                        c.beginPath(); c.ellipse(333, 149, 614, 341); c.stroke()
                        c.fillStyle = "#e8d4fa"
                        c.beginPath(); c.arc(345, 318, 3, 0, 2 * Math.PI); c.fill()
                    } else {
                        function plane(points, fill) {
                            c.beginPath(); c.moveTo(points[0], points[1])
                            for (let i = 2; i < points.length; i += 2) c.lineTo(points[i], points[i + 1])
                            c.closePath(); c.fillStyle = fill; c.fill()
                        }
                        plane([439,190,859,190,819,342,780,342,774,366,408,366,420,321,404,321], "#283842")
                        plane([439,190,859,190,853,211,434,211], "#354b56")
                        plane([439,190,502,190,500,196,437,196], "#ffc27a")
                        plane([454,334,824,334,817,363,446,363], "#e9ddc6")
                        for (let i = 0; i < 5; i++)
                            plane([809+i*7,198,812+i*7,198,810+i*7,204,807+i*7,204], "#92a0a0")
                    }
                }
            }
            Row {
                x: 51; y: 39; spacing: 11
                Glyph { width: 18; height: 18; mark: "lock"; ink: win.accent }
                Legend { text: "ZÆTHERION"; font.bold: true }
            }
            Legend { anchors.right: parent.right; anchors.rightMargin: 51; y: 40; text: "SESSION LOCK" }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                y: win.fluid ? 190 : 194
                text: "06:42"; color: win.ink
                font.family: win.fluid ? "DejaVu Serif" : "Inter Display"
                font.pixelSize: win.clockSize; font.italic: true
                font.weight: win.fluid ? Font.Normal : Font.Black
                font.letterSpacing: win.fluid ? -4 : -2
            }
            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                y: win.fluid ? 332 : 334
                text: "Tuesday, 24 November 2026"
                color: win.fluid ? win.ink : "#233139"
                font.family: win.fluid ? "DejaVu Serif" : "Inter"
                font.pixelSize: win.dateSize
                font.weight: win.fluid ? Font.Normal : Font.DemiBold
            }
            Item {
                id: field
                width: win.fluid ? 320 : 376; height: 56
                x: (parent.width - width) / 2 + offset; y: win.fluid ? 392 : 389
                readonly property real phase: Math.min(1, Math.max(0, win.elapsed / 320))
                readonly property real offset: win.reduced ? 0 : (win.fluid ? 6 : 10)
                      * Math.sin(phase * (win.fluid ? 2 : 3) * Math.PI * 2) * (1 - phase)
                Canvas {
                    anchors.fill: parent
                    property bool failed: win.failed
                    onFailedChanged: requestPaint()
                    onPaint: {
                        const c = getContext("2d")
                        c.reset(); c.lineWidth = 1.5
                        c.fillStyle = win.fluid ? "#322c44" : "#1c292f"
                        c.strokeStyle = failed ? win.alert : win.accent
                        c.beginPath()
                        if (win.fluid) c.roundedRect(1, 1, width-2, height-2, 27, 27)
                        else {
                            c.moveTo(14, 1); c.lineTo(width-1, 1)
                            c.lineTo(width-15, height-1); c.lineTo(1, height-1); c.closePath()
                        }
                        c.fill(); c.stroke()
                    }
                }
                Glyph { x: 23; anchors.verticalCenter: parent.verticalCenter; width: 21; height: 21; mark: "lock"; ink: win.accent }
                Label {
                    x: 58; anchors.verticalCenter: parent.verticalCenter
                    text: win.elapsed < 0 ? "••••••" : "Password"
                    font.letterSpacing: win.elapsed < 0 ? 4 : 0
                }
                Glyph { anchors.right: parent.right; anchors.rightMargin: 23; anchors.verticalCenter: parent.verticalCenter
                    width: 21; height: 21; mark: "enter"; ink: win.accent }
            }
            Rectangle {
                visible: win.failed
                anchors.horizontalCenter: parent.horizontalCenter
                y: win.fluid ? 455 : 453
                width: 188; height: 26; radius: win.fluid ? 13 : 0; color: "#382e34"
                Legend { anchors.centerIn: parent; color: win.alert; text: "> AUTH FAILED · " + win.attempts }
            }
            Rectangle {
                x: win.fluid ? 88 : 0; y: win.fluid ? 611 : 614
                width: win.fluid ? 1104 : 1280; height: win.fluid ? 77 : 106
                color: win.fluid ? "#282738" : "#1c2931"; radius: win.fluid ? height / 2 : 0
                border.width: win.fluid ? 1 : 0; border.color: "#625b74"
                Rectangle { visible: !win.fluid; width: parent.width; height: 1; color: "#626b6d" }
                Row {
                    x: win.fluid ? 33 : 52; anchors.verticalCenter: parent.verticalCenter; spacing: 16
                    Rectangle {
                        width: 48; height: 48; radius: win.fluid ? 24 : 0
                        color: win.fluid ? "#4d425d" : "#394b51"; clip: true
                        Row {
                            anchors.centerIn: parent; spacing: 3
                            Repeater {
                                model: [9, 18, 26, 13, 20, 8]
                                Rectangle { required property int modelData; y: (26-height)/2
                                    width: 2; height: modelData; color: win.accent }
                            }
                        }
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter; spacing: 2
                        Label { text: "Low Moon"; font.pixelSize: win.track; font.weight: Font.DemiBold }
                        Legend { text: "Vesper Field"; font.letterSpacing: 0.25; color: "#c3c3cb" }
                    }
                }
                Row {
                    anchors.centerIn: parent; spacing: 10
                    Repeater {
                        model: ["previous", "pause", "next"]
                        Rectangle {
                            required property string modelData
                            width: 47; height: 40; radius: win.fluid ? 20 : 0
                            color: modelData === "pause" ? win.accent : "transparent"
                            Glyph { anchors.centerIn: parent; width: 21; height: 21
                                mark: parent.modelData; ink: parent.modelData === "pause" ? "#262a32" : win.ink }
                        }
                    }
                }
                Row {
                    anchors.right: parent.right; anchors.rightMargin: win.fluid ? 28 : 52
                    anchors.verticalCenter: parent.verticalCenter; spacing: 12
                    Glyph { anchors.verticalCenter: parent.verticalCenter; width: 24; height: 24; mark: "battery" }
                    Legend { anchors.verticalCenter: parent.verticalCenter; text: "76%" }
                    Item { width: 13; height: 1 }
                    Rectangle {
                        width: 171; height: 41; radius: win.fluid ? 21 : 0
                        color: win.holdProgress > 0 ? "#45404a" : "transparent"; border.color: win.fluid ? "#7c738e" : "#627277"
                        Rectangle {
                            x: 15; y: parent.height - 5; width: (parent.width - 30) * win.holdProgress
                            height: 2; color: win.accent; visible: win.holdProgress > 0
                        }
                        MouseArea {
                            anchors.fill: parent
                            onPressed: fill.restart()
                            onReleased: { fill.stop(); win.holdProgress = 0 }
                            onCanceled: { fill.stop(); win.holdProgress = 0 }
                        }
                        NumberAnimation { id: fill; target: win; property: "holdProgress"; from: 0; to: 1; duration: 1000 }
                        Row { anchors.centerIn: parent; spacing: 9
                            Glyph { width: 17; height: 17; mark: "power"; ink: win.accent }
                            Legend { text: "Hold for power"; font.letterSpacing: 0.2 }
                        }
                    }
                }
            }
        }
    }
    NumberAnimation { id: replay; target: win; property: "elapsed"; from: 0; to: 400; duration: 400 }
    Timer {
        running: win.args.includes("--out"); interval: 200
        onTriggered: sheet.grabToImage(image => Qt.exit(image.saveToFile(win.argument("--out", "")) ? 0 : 1))
    }
}
