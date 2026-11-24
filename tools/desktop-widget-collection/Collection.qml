pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
import "../password-lock-study" as Lock

Window {
    id: win
    width: 1280; height: 720; visible: true
    readonly property var args: Qt.application.arguments
    readonly property bool fluid: args.includes("--fluid")
    property bool alternate: args.includes("--studio")
    property bool editing: args.includes("--presets")
    property bool occupied: args.includes("--occupied")
    readonly property bool silentTrack: args.includes("--no-track")
    readonly property bool noLyrics: args.includes("--no-lyrics")
    readonly property color paper: fluid ? "#342e43" : "#233039"
    readonly property color ink: fluid ? "#f7eef7" : "#fff1de"
    readonly property color accent: fluid ? "#e6c8ee" : "#ffc476"
    readonly property color subInk: fluid ? "#d2c4d4" : "#c4cccd"
    readonly property int fine: 13
    readonly property int read: 18
    readonly property int subhead: 23
    readonly property int headline: 41
    readonly property int quoteSize: 29

    component Caption: Text {
        color: win.subInk; font.family: "DejaVu Sans Mono"; font.pixelSize: win.fine
        font.letterSpacing: 1.2
    }
    component Copy: Text {
        color: win.ink; font.family: "Inter"; font.pixelSize: win.read
    }
    component Plane: Canvas {
        property color fill: win.paper
        onFillChanged: requestPaint()
        anchors.fill: parent
        onPaint: {
            const c = getContext("2d")
            c.reset(); c.fillStyle = fill; c.beginPath()
            if (win.fluid) {
                c.roundedRect(0,0,width,height,26,26)
            } else {
                c.moveTo(12,0); c.lineTo(width,0); c.lineTo(width,height-17)
                c.lineTo(width-17,height); c.lineTo(0,height); c.lineTo(0,12); c.closePath()
            }
            c.fill()
        }
    }
    Item {
        id: sheet
        anchors.fill: parent; focus: true
        Keys.onSpacePressed: win.occupied = !win.occupied
        Keys.onTabPressed: win.editing = !win.editing
        Keys.onLeftPressed: win.alternate = false
        Keys.onRightPressed: win.alternate = true
        Item {
            id: desk
            width: 1280; height: 720; anchors.centerIn: parent
            scale: Math.min(sheet.width/width,sheet.height/height)
            Lock.Sky { anchors.fill: parent; fluid: win.fluid }
            Loader {
                id: widgets
                anchors.fill: parent
                active: !win.occupied
                sourceComponent: Item {
                    Item {
                        x: win.alternate ? 656 : 56; y: win.alternate ? 85 : 90
                        width: 500; height: 214
                        Plane {}
                        Print { visible: !win.silentTrack; x: 16; y: 18; width: win.fluid ? 146 : 108; height: 103; subject: "sleeve"; fluid: win.fluid }
                        Column {
                            x: win.silentTrack ? 22 : win.fluid ? 184 : 145; y: 17; spacing: 3
                            Caption { text: "NOW PLAYING"; color: win.accent }
                            Copy { text: win.silentTrack ? "No track" : "Low Moon"; font.pixelSize: win.headline
                                font.family: win.fluid ? "DejaVu Serif" : "Inter Display"
                                font.italic: win.fluid; font.weight: win.fluid ? Font.Normal : Font.Black }
                            Copy { visible: !win.silentTrack; text: "Vesper Field" }
                        }
                        Rectangle { x: 22; y: 140; width: 456; height: 2; color: "#62626b"
                            Rectangle { width: win.silentTrack ? 0 : 165; height: 2; color: win.accent } }
                        Copy { x: 23; y: 161; font.pixelSize: win.subhead; font.italic: true
                            text: win.silentTrack ? "—" : win.noLyrics ? "Lyrics unavailable" : "Leave a light along the shore." }
                    }
                    Item {
                        x: win.alternate ? 356 : 756; y: win.alternate ? 465 : 90
                        width: 438; height: 150
                        Plane { fill: win.fluid ? "#413c52" : "#303f49" }
                        Column { x: 23; y: 19; spacing: 5
                            Caption { text: "SKY"; color: win.accent }
                            Copy { text: "First light"; font.pixelSize: win.subhead }
                            Copy { text: "Sunrise  06:58"; color: win.subInk }
                        }
                        Canvas {
                            x: 197; y: 20; width: 219; height: 109
                            onPaint: {
                                const c = getContext("2d"); c.reset()
                                c.strokeStyle = "#bdb7bb"; c.lineWidth = 1
                                c.beginPath(); c.moveTo(4,79); c.lineTo(218,79); c.stroke()
                                c.strokeStyle = win.accent; c.setLineDash([2,4])
                                c.beginPath(); c.moveTo(12,95); c.quadraticCurveTo(111,-57,217,79); c.stroke()
                                c.fillStyle = win.accent; c.beginPath(); c.arc(35,65,9,0,2*Math.PI); c.fill()
                            }
                        }
                    }
                    Item {
                        x: win.alternate ? 56 : 156; y: win.alternate ? 85 : 355
                        width: 338; height: 178
                        Plane { fill: win.fluid ? "#dad0dd" : "#e8d9b9" }
                        Column { x: 24; y: 20; spacing: 10
                            Caption { text: "NOTES"; color: "#504858" }
                            Copy { text: "Studio list"; color: "#292833"; font.pixelSize: win.subhead; font.bold: true }
                            Copy { text: "Cut the paper to size.\nBring the blue sketchbook."; color: "#34333a"; lineHeight: 1.28 }
                        }
                    }
                    Item {
                        x: win.alternate ? 656 : 56; y: win.alternate ? 369 : 563
                        width: 510; height: 65
                        Plane {}
                        Copy { x: 24; anchors.verticalCenter: parent.verticalCenter; font.pixelSize: win.quoteSize
                            font.family: "DejaVu Serif"; font.italic: true; text: "A quieter kind of morning." }
                    }
                    Item {
                        x: win.alternate ? 56 : 856; y: win.alternate ? 304 : 322
                        width: 260; height: 205
                        Plane { fill: "#e3dbc6" }
                        Print { x: 10; y: 10; width: 240; height: 156 }
                        Caption { x: 13; y: 176; text: "West gallery"; color: "#3a4140" }
                    }
                }
            }
            Rectangle {
                visible: win.editing && !win.occupied
                anchors.horizontalCenter: parent.horizontalCenter; y: 636
                width: 566; height: 62; radius: win.fluid ? 31 : 0; color: win.paper
                Row {
                    anchors.centerIn: parent; spacing: 10
                    Caption { anchors.verticalCenter: parent.verticalCenter; text: "DISPLAY 1  /  PRESETS" }
                    Repeater {
                        model: ["Morning", "Studio"]
                        Rectangle {
                            id: choice
                            required property int index
                            required property string modelData
                            readonly property bool selected: (index === 1) === win.alternate
                            width: 136; height: 40; color: selected ? win.accent : "transparent"
                            radius: win.fluid ? 20 : 0
                            Row { anchors.centerIn: parent; spacing: 9
                                Item { width: 25; height: 20
                                    Rectangle { x: choice.index ? 14 : 0; y: 2; width: 11; height: 7; color: choice.selected ? win.paper : win.ink }
                                    Rectangle { x: choice.index ? 0 : 16; y: 4; width: 8; height: 4; color: choice.selected ? win.paper : win.ink }
                                    Rectangle { x: choice.index ? 2 : 6; y: 12; width: 8; height: 5; color: choice.selected ? win.paper : win.ink }
                                }
                                Copy { text: choice.modelData; color: choice.selected ? win.paper : win.ink }
                            }
                            MouseArea { anchors.fill: parent; onClicked: win.alternate = choice.index === 1 }
                        }
                    }
                }
            }
        }
    }
    Timer {
        interval: 200; running: win.args.includes("--out")
        onTriggered: sheet.grabToImage(image => Qt.exit(image.saveToFile(win.args[win.args.indexOf("--out")+1]) ? 0 : 1))
    }
}
