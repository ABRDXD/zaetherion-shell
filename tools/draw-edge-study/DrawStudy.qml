pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
import "../password-lock-study" as Lock
import "../desktop-widget-collection" as Widgets

Window {
    id: win
    width: 1280; height: 720; visible: true
    readonly property var args: Qt.application.arguments
    readonly property bool fluid: args.includes("--fluid")
    property bool edge: args.includes("--edge")
    property bool blank: args.includes("--blank")
    property bool marked: !args.includes("--empty")
    property bool redoable: false
    property real opened: args.includes("--closed") ? 0 : args.includes("--half") ? 0.5 : 1
    Behavior on opened { enabled: !win.args.includes("--reduced"); NumberAnimation { duration: 210; easing.type: Easing.OutCubic } }
    property int tool: 1
    property int swatch: 0
    readonly property var colors: ["#ffbd72", "#deabdc", "#91d6c9"]
    readonly property color accent: fluid ? "#e0c3ec" : "#ffbc70"
    readonly property color paper: fluid ? "#322d41" : "#22313b"
    readonly property color ink: "#faf1e5"
    readonly property int caption: 14
    readonly property int body: 17
    readonly property int titleSize: 28
    readonly property int noteSize: 22
    readonly property var toolNames: ["Pen", "Highlighter", "Shape", "Text"]
    component Label: Text {
        font.family: "Inter"; color: win.ink; font.pixelSize: win.body
    }
    component Tag: Text {
        color: win.ink; font.family: "DejaVu Sans Mono"; font.pixelSize: win.caption
        font.letterSpacing: 1.1
    }
    component Back: Canvas {
        anchors.fill: parent
        onPaint: {
            const c = getContext("2d"); c.reset()
            c.fillStyle = win.paper; c.beginPath()
            if (win.fluid) c.roundedRect(0,0,width,height,23,23)
            else {
                c.moveTo(13,0); c.lineTo(width,0); c.lineTo(width,height-13)
                c.lineTo(width-13,height); c.lineTo(0,height); c.lineTo(0,13); c.closePath()
            }
            c.fill()
        }
    }
    component Mark: Canvas {
        id: symbol
        required property int index
        required property color ink
        onInkChanged: requestPaint()
        onPaint: {
            const c = getContext("2d"); c.reset(); c.scale(width/24,height/24)
            c.strokeStyle = ink; c.fillStyle = ink; c.lineWidth = 1.7; c.lineJoin = "round"
            c.beginPath()
            if (index < 2) {
                c.moveTo(4,20); c.lineTo(6,13); c.lineTo(16,3); c.lineTo(21,8)
                c.lineTo(11,18); c.closePath()
                if (index === 1) c.fill(); else c.stroke()
                c.beginPath(); c.moveTo(3,22); c.lineTo(12,22)
            } else if (index === 2) {
                c.rect(3,5,12,12); c.moveTo(22,15); c.arc(16,15,6,0,Math.PI*2)
            } else if (index === 3) {
                c.moveTo(4,7); c.lineTo(4,4); c.lineTo(20,4); c.lineTo(20,7)
                c.moveTo(12,4); c.lineTo(12,21); c.moveTo(7,21); c.lineTo(17,21)
            } else {
                c.rect(3,2,18,20); c.moveTo(6,8); c.lineTo(18,8)
                for (const x of [7,12,17]) for (const y of [12,17]) c.fillRect(x-1,y-1,2,2)
            }
            c.stroke()
        }
    }
    component Tool: Rectangle {
        id: choice
        required property int index
        readonly property bool active: win.tool === index
        width: win.fluid ? 145 : 155; height: 43; radius: win.fluid ? 22 : 0
        color: active ? win.accent : "transparent"
        Row {
            x: 11; anchors.verticalCenter: parent.verticalCenter; spacing: 9
            Mark { width: 23; height: 23; index: choice.index; ink: choice.active ? win.paper : win.ink }
            Label { anchors.verticalCenter: parent.verticalCenter; text: win.toolNames[choice.index]
                color: choice.active ? win.paper : win.ink }
        }
        MouseArea { anchors.fill: parent; onClicked: win.tool = choice.index }
    }
    component Palette: Row {
        spacing: 10
        Repeater {
            model: win.colors
            Rectangle { id: chip
                required property color modelData; required property int index
                width: 27; height: 27; radius: win.fluid ? 14 : 1
                color: modelData; border.width: index === win.swatch ? 2 : 0; border.color: "#ffffff"
                Rectangle { visible: chip.index === win.swatch; anchors.centerIn: parent; width: 7; height: 7; radius: 4; color: win.paper }
                MouseArea { anchors.fill: parent; onClicked: win.swatch = chip.index }
            }
        }
    }
    Item {
        id: sheet
        anchors.fill: parent; focus: true
        Keys.onEscapePressed: { win.edge = true; win.opened = 1 }
        Item {
            id: desk
            width: 1280; height: 720; anchors.centerIn: parent
            scale: Math.min(sheet.width/width, sheet.height/height)
            Lock.Sky { anchors.fill: parent; fluid: win.fluid }
            Item {
                visible: !win.edge; anchors.fill: parent
                Rectangle {
                    anchors.fill: parent
                    color: win.fluid ? "#ded9db" : "#e6dfce"
                }
                Widgets.Print { visible: !win.blank; anchors.fill: parent }
                Item {
                    x: 555; y: 287; width: 350; height: 180
                    visible: win.marked
                    Canvas {
                        anchors.fill: parent
                        property color stroke: win.colors[win.swatch]
                        onStrokeChanged: requestPaint()
                        onPaint: {
                            const c = getContext("2d"); c.reset()
                            c.strokeStyle = stroke; c.lineWidth = 14; c.globalAlpha = 0.72; c.lineCap = "round"
                            c.beginPath(); c.moveTo(13,140); c.quadraticCurveTo(117,107,230,75); c.stroke()
                            c.globalAlpha = 1; c.lineWidth = 3; c.strokeStyle = "#26333a"
                            c.beginPath(); c.moveTo(340,24); c.bezierCurveTo(327,45,268,37,245,66)
                            c.lineTo(251,50); c.moveTo(245,66); c.lineTo(262,61); c.stroke()
                        }
                    }
                }
                Rectangle {
                    visible: win.marked; x: 873; y: 268; width: 177; height: 34; color: "#f4e8cd"
                    Label { anchors.centerIn: parent; text: "Align the canopy"; font.pixelSize: win.noteSize; color: "#26333a"; font.italic: true }
                }
                Item {
                    x: 32; y: 25; width: 365; height: 62
                    Back {}
                    Row {
                        x: 20; anchors.verticalCenter: parent.verticalCenter; spacing: 22
                        Label { text: "Draw"; font.pixelSize: win.titleSize; font.weight: Font.Bold }
                        Repeater {
                            model: ["Frozen", "Blank"]
                            Label {
                                required property int index; required property string modelData
                                readonly property bool chosen: win.blank === (index === 1)
                                anchors.verticalCenter: parent.verticalCenter; text: modelData
                                color: chosen ? win.accent : win.ink
                                Rectangle { visible: parent.chosen; width: parent.width; height: 2
                                    anchors.top: parent.bottom; anchors.topMargin: 3; color: win.accent }
                                MouseArea { anchors.fill: parent; onClicked: win.blank = parent.index === 1 }
                            }
                        }
                    }
                }
                Item {
                    anchors.right: parent.right; anchors.rightMargin: 32; y: 25; width: 327; height: 62
                    Back {}
                    Row {
                        anchors.centerIn: parent; spacing: 17
                        Repeater {
                            model: ["Undo", "Redo", "Copy", "Save"]
                            Label {
                                required property int index; required property string modelData
                                text: modelData; opacity: index === 0 && !win.marked || index === 1 && !win.redoable ? 0.43 : 1
                                color: index === 3 ? win.accent : win.ink
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        if (parent.index === 0 && win.marked) { win.marked = false; win.redoable = true }
                                        else if (parent.index === 1 && win.redoable) { win.marked = true; win.redoable = false }
                                    }
                                }
                            }
                        }
                    }
                }
                Item {
                    x: win.fluid ? (parent.width-width)/2 : 32; y: win.fluid ? 617 : 202
                    width: win.fluid ? 758 : 179; height: win.fluid ? 70 : 276
                    Back {}
                    Grid {
                        x: 12; y: 13; columns: win.fluid ? 4 : 1; spacing: 4
                        Repeater { model: 4; Tool {} }
                    }
                    Palette { x: win.fluid ? 635 : 24; y: win.fluid ? 22 : 223 }
                }
            }
            MouseArea {
                visible: win.edge
                width: Math.max(5, 265 * win.opened); height: 190; y: 265
                anchors.right: parent.right; hoverEnabled: true
                onEntered: win.opened = 1
                onExited: if (!edgePlane.hovered) win.opened = 0
            }
            Item {
                id: edgePlane
                readonly property bool hovered: edgeHover.hovered
                HoverHandler { id: edgeHover; onHoveredChanged: if (!hovered) win.opened = 0 }
                visible: win.edge; width: 277; height: 190; y: 265; x: 1280 - (width-12) * win.opened
                Back {}
                Tag { x: 25; y: 19; text: "QUICK ACTIONS"; color: win.accent }
                Repeater {
                    model: ["Calculator", "Draw"]
                    Rectangle {
                        id: action
                        required property int index; required property string modelData
                        x: 14; y: 47 + 60*index; width: 234; height: 53; radius: win.fluid ? 27 : 0
                        color: index === 1 ? win.accent : "transparent"
                        Row { x: 12; anchors.verticalCenter: parent.verticalCenter; spacing: 16
                            Mark { index: action.index === 0 ? 4 : 0; width: 23; height: 23; ink: action.index ? win.paper : win.ink }
                            Label { text: action.modelData; color: action.index ? win.paper : win.ink }
                        }
                        MouseArea { anchors.fill: parent; onClicked: if (action.index === 1) win.edge = false }
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
