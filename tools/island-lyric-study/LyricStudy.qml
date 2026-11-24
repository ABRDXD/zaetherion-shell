pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window

Window {
    id: win
    width: 790; height: 356; visible: true
    readonly property var args: Qt.application.arguments
    property real elapsed: args.includes("--at") ? Number(args[args.indexOf("--at")+1]) : 900
    readonly property bool reduced: args.includes("--reduced")
    readonly property bool fallback: args.includes("--no-lyrics") || args.includes("--released")
    readonly property int small: 13
    readonly property int titleSize: 16
    readonly property var lyrics: ["Low on the water", "Light on the shore"]
    readonly property real t: Math.min(1,Math.max(0,(elapsed-1000)/200))
    readonly property real mix: reduced ? (elapsed >= 1000 ? 1 : 0) : t
    component Slot: Item {
        id: slot
        required property bool fluid
        readonly property color accent: fluid ? "#dfc4ec" : "#ffc074"
        width: fluid ? 240 : 140; height: 27; clip: true
        Repeater {
            model: win.fallback ? ["Low Moon"] : win.lyrics
            Text {
                id: line
                required property int index; required property string modelData
                width: slot.width
                elide: Text.ElideRight; wrapMode: Text.NoWrap
                color: win.fallback ? "#f2eade" : slot.accent
                font.family: slot.fluid ? "Inter" : "DejaVu Sans Mono"
                font.pixelSize: win.titleSize; font.weight: slot.fluid ? Font.Medium : Font.Normal
                text: modelData
                readonly property real offset: win.reduced || win.fallback ? 0
                    : index === 0 ? -win.mix : 1-win.mix
                opacity: win.fallback ? 1 : index === 0 ? 1-win.mix : win.mix
                x: slot.fluid ? 0 : offset*10
                y: (slot.height-height)/2 + (slot.fluid ? offset*8 : 0)
            }
        }
    }
    Item {
        id: sheet
        anchors.fill: parent
        Rectangle { anchors.fill: parent; color: "#20252f" }
        Repeater {
            model: ["Angular", "Fluid"]
            Item {
                id: sample
                required property int index; required property string modelData
                x: 44; y: index ? 188 : 37; width: 700; height: 122
                Text {
                    text: sample.modelData + (sample.index ? "   /   240 px" : "   /   140 px")
                    color: "#d7d5d1"; font.family: "DejaVu Sans Mono"; font.pixelSize: win.small
                }
                Rectangle {
                    y: 33; width: 648; height: 77; radius: sample.index ? 39 : 2; color: "#141b23"
                    Item {
                        anchors.centerIn: parent; width: sample.index ? 258 : 158; height: 27; scale: 2
                        Rectangle { width: 3; height: 12; y: 8; color: sample.index ? "#dfc4ec" : "#ffc074" }
                        Slot { x: 14; fluid: sample.index === 1 }
                    }
                }
            }
        }
    }
    Timer {
        interval: 120; running: win.args.includes("--out")
        onTriggered: sheet.grabToImage(image => Qt.exit(image.saveToFile(win.args[win.args.indexOf("--out")+1]) ? 0 : 1))
    }
}
