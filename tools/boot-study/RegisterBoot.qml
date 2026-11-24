pragma ComponentBehavior: Bound
import QtQuick

Item {
    id: boot
    required property int current
    required property string currentText
    required property real progress
    required property var events
    required property var starts
    readonly property color ink: "#f2efdf"
    readonly property color paper: "#20232a"
    readonly property color signal: "#ffd064"

    Item {
        id: field
        width: 824
        height: 306
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -12
        scale: Math.min(1, (boot.width - 40) / width, (boot.height - 80) / height)
        Canvas {
            anchors.fill: parent
            onPaint: {
                const c = getContext("2d");
                c.fillStyle = boot.paper;
                c.fillRect(0, 24, width, height - 48);
                // The title wedge has one 78° outside cut and a straight inside edge.
                c.fillStyle = boot.ink;
                c.beginPath();
                c.moveTo(66, 0); c.lineTo(425, 0);
                c.lineTo(425, 306); c.lineTo(1, 306);
                c.closePath(); c.fill();
            }
        }

        FontMetrics {
            id: type
            font.family: "DejaVu Sans"
            font.weight: Font.Black
            font.pixelSize: 345 // scale: study fixture, the mock's size
        }
        Item {
            id: press
            x: 78; y: 26
            width: 347
            height: 254
            clip: true
            readonly property rect bounds: type.tightBoundingRect("Æ")
            Repeater {
                model: boot.events.length
                Item {
                    id: piece
                    required property int index
                    readonly property real travel: Math.max(0, Math.min(1, boot.progress * boot.events.length - index))
                    readonly property int sliceY: Math.round(press.bounds.height * index / boot.events.length)
                    x: 0; y: sliceY
                    width: press.width
                    height: Math.round(press.bounds.height * (index + 1) / boot.events.length) - sliceY
                    clip: true
                    Text {
                        x: -press.bounds.x + (1 - piece.travel) * 64
                        y: -baselineOffset - press.bounds.y - piece.sliceY
                        text: "Æ"
                        font: type.font
                        color: piece.index > boot.current ? "#cac7bb" : boot.paper
                    }
                }
            }
        }

        // Each entry has its own position in the index. Selection moves as the
        // fixture log advances. A finished entry keeps its timestamp and text.
        Column {
            x: 444; y: 48
            spacing: 6
            Repeater {
                model: boot.events.length
                Item {
                    id: entry
                    required property int index
                    readonly property bool selected: index === boot.current
                    width: 363
                    height: 48
                    Canvas {
                        anchors.fill: parent
                        visible: entry.selected
                        onPaint: {
                            const c = getContext("2d");
                            c.fillStyle = boot.ink;
                            c.beginPath();
                            c.moveTo(11, 4); c.lineTo(width, 4);
                            c.lineTo(width - 9, height - 4); c.lineTo(2, height - 4);
                            c.closePath(); c.fill();
                            c.fillStyle = boot.signal;
                            c.fillRect(11, 0, width - 11, 1);
                            c.fillRect(0, height - 1, width - 9, 1);
                        }
                    }
                    Text {
                        x: 21
                        anchors.verticalCenter: parent.verticalCenter
                        text: boot.starts[entry.index] + " ms"
                        visible: entry.index <= boot.current
                        font.family: "JetBrains Mono"
                        font.pixelSize: 14 // scale: study fixture, the mock's size
                        color: entry.selected ? boot.paper : "#aeb5bd"
                    }
                    Text {
                        x: 116
                        anchors.verticalCenter: parent.verticalCenter
                        text: entry.selected ? boot.currentText : entry.index < boot.current ? boot.events[entry.index] : ""
                        font.family: "Roboto Condensed"
                        font.weight: entry.selected ? Font.Bold : Font.Normal
                        font.pixelSize: entry.selected ? 26 : 21 // scale: study fixture, the mock's size
                        color: entry.selected ? boot.paper : boot.ink
                    }
                }
            }
        }
    }
}
