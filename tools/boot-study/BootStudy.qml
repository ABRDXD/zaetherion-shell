pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window

Window {
    id: window
    width: 960
    height: 540
    title: "ZÆTHERION boot study"
    readonly property var args: Qt.application.arguments
    readonly property bool fluid: args.includes("--fluid")
    readonly property bool aperture: args.includes("--aperture")
    readonly property bool reduced: args.includes("--reduced-motion")
    readonly property bool exporting: args.includes("--out")
    visible: !reduced || exporting
    color: fluid ? "#141f24" : "#181c22"
    readonly property color ink: "#f1eee5"
    readonly property color quiet: fluid ? "#a5babd" : "#afafb1"
    readonly property color accent: fluid ? "#a8d9d1" : "#eac498"
    readonly property color rule: fluid ? "#41525a" : "#454950"
    readonly property string sans: fluid ? "Noto Sans" : "Roboto Condensed"
    readonly property string mono: "DejaVu Sans Mono"
    readonly property var events: ["Reading palette", "Loading typefaces", "Opening workspace", "Session ready"]
    readonly property var starts: [0, 320, 660, 1020]
    readonly property int current: elapsed >= starts[3] ? 3 : elapsed >= starts[2] ? 2 : elapsed >= starts[1] ? 1 : 0
    readonly property real progress: (current + Math.min(1, (elapsed - starts[current]) / (16 * events[current].length))) / events.length
    property int elapsed: exporting ? (args.includes("--at") ? Number(args[args.indexOf("--at") + 1]) : 1170) : 0

    function typed(index) {
        return events[index].slice(0, Math.max(0, Math.floor((elapsed - starts[index]) / 16)));
    }
    function stamp(index) {
        return (starts[index] / 1000).toFixed(3) + " s";
    }

    Rectangle {
        id: scene
        color: window.color
        anchors.fill: parent
        focus: true
        Keys.priority: Keys.BeforeItem
        Keys.onPressed: event => { event.accepted = true; Qt.quit(); }

        Loader {
            anchors.fill: parent
            active: !window.reduced
            sourceComponent: window.aperture ? apertureFace : printerFace
        }
        Text {
            visible: !window.reduced
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 36
            text: "Press any key to skip"
            font.family: window.sans
            font.pixelSize: 15
            color: window.quiet
        }
    }

    component Brand: Text {
        text: "ZÆTHERION"
        font.family: window.sans
        font.weight: Font.DemiBold
        font.letterSpacing: 4
        color: window.ink
    }

    Component {
        id: printerFace
        Item {
            Item {
                anchors.centerIn: parent
                width: 570
                height: 272
                Brand { x: 1; y: 0; font.pixelSize: 39 }
                Text {
                    anchors.right: parent.right
                    y: 29
                    text: "Session log"
                    font.family: window.mono
                    font.pixelSize: 13
                    color: window.quiet
                }
                Rectangle {
                    y: 66
                    width: parent.width
                    height: 2
                    color: window.rule
                    Rectangle {
                        width: parent.width * window.progress
                        height: parent.height
                        radius: window.fluid ? 1 : 0
                        color: window.accent
                    }
                }
                Column {
                    y: 93
                    width: parent.width
                    spacing: 6
                    Repeater {
                        model: window.events.length
                        Item {
                            id: line
                            required property int index
                            visible: index <= window.current
                            width: parent.width
                            height: 37
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: window.stamp(line.index)
                                font.family: window.mono
                                font.pixelSize: 14
                                color: window.quiet
                            }
                            Text {
                                id: words
                                x: 126
                                anchors.verticalCenter: parent.verticalCenter
                                text: window.typed(line.index)
                                font.family: window.mono
                                font.pixelSize: 21
                                color: line.index === window.current ? window.ink : window.quiet
                            }
                            Rectangle {
                                x: words.x + words.implicitWidth + 5
                                anchors.verticalCenter: parent.verticalCenter
                                visible: line.index === window.current && window.elapsed < 1260
                                width: window.fluid ? 3 : 9
                                height: 20
                                radius: window.fluid ? 1.5 : 0
                                color: window.accent
                            }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: apertureFace
        Item {
            Item {
                width: 745
                height: 240
                anchors.centerIn: parent
                Aperture {
                    width: 222
                    height: width
                    anchors.verticalCenter: parent.verticalCenter
                    progress: window.progress
                    fluid: window.fluid
                    accent: window.accent
                }
                Item {
                    x: 278
                    width: parent.width - x
                    anchors.verticalCenter: parent.verticalCenter
                    height: 150
                    Brand { font.pixelSize: 17 }
                    Text {
                        y: 52
                        text: window.current ? window.events[window.current - 1] : ""
                        font.family: window.mono
                        font.pixelSize: 17
                        color: window.quiet
                    }
                    Text {
                        id: currentLine
                        y: 77
                        text: window.typed(window.current)
                        font.family: window.sans
                        font.weight: Font.Medium
                        font.pixelSize: 43
                        color: window.ink
                    }
                    Rectangle {
                        x: currentLine.implicitWidth + 5
                        y: currentLine.y + currentLine.height * .78
                        visible: window.elapsed < 1260
                        width: 16
                        height: 3
                        radius: window.fluid ? 1.5 : 0
                        color: window.accent
                    }
                }
            }
        }
    }

    NumberAnimation {
        id: playback
        target: window
        property: "elapsed"
        from: 0
        to: 1500
        duration: 1500
        onFinished: Qt.quit()
    }
    Component.onCompleted: {
        if (!exporting) {
            if (reduced) Qt.callLater(Qt.quit);
            else playback.start();
        }
    }
    Timer {
        interval: 150
        running: window.exporting
        onTriggered: {
            const path = window.args[window.args.indexOf("--out") + 1];
            scene.grabToImage(result => Qt.exit(result.saveToFile(path) ? 0 : 1));
        }
    }
}
