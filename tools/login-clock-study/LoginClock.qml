pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
import QtCore
import "../widget-study" as Widgets

Window {
    id: window
    width: 1120
    height: 630
    visible: true
    color: "#16191e"
    title: "Register into Day index"
    readonly property var args: Qt.application.arguments
    readonly property bool reduced: args.includes("--reduced-motion")
    readonly property bool exporting: args.includes("--out")
    property bool occupied: args.includes("--occupied")
    property int elapsed: reduced ? 1500 : (args.includes("--at")
                          ? Math.max(0, Math.min(1500, Number(args[args.indexOf("--at") + 1]))) : 0)
    readonly property var starts: [0, 275, 565, 840]
    readonly property var lines: ["fartd online", "island at rest",
                                  occupied ? "workspace occupied" : "workspace empty",
                                  occupied ? "widgets asleep" : "clock on desktop"]
    readonly property int lineIndex: elapsed < starts[1] ? 0 : elapsed < starts[2] ? 1 : elapsed < starts[3] ? 2 : 3
    readonly property int letters: Math.floor((elapsed - starts[lineIndex]) / 14)
    readonly property real impression: (lineIndex + Math.min(1, letters / lines[lineIndex].length)) / 4
    readonly property real travel: Math.max(0, Math.min(1, (elapsed - 1130) / 370))
    readonly property real fold: travel * travel * (3 - 2 * travel)
    readonly property bool landed: elapsed >= 1500
    readonly property url fonts: StandardPaths.writableLocation(StandardPaths.HomeLocation)
                                  + "/.config/dms/plugins/modernClock/fonts/"
    FontLoader { id: displayFont; source: window.fonts + "Anurati.otf" }
    readonly property string displayFamily: displayFont.status === FontLoader.Ready ? displayFont.name
                                        : Qt.fontFamilies().includes("Anurati") ? "Anurati" : "DejaVu Sans"
    function settle() {
        play.stop();
        elapsed = 1500;
    }

    Rectangle {
        id: scene
        anchors.fill: parent
        color: window.color
        focus: true
        Keys.onPressed: event => {
            if (!window.landed) {
                event.accepted = true;
                window.settle();
            } else if (event.key === Qt.Key_Space && !event.isAutoRepeat) {
                event.accepted = true;
                window.occupied = !window.occupied;
            }
        }

        Item {
            id: board
            width: 1120
            height: 630
            scale: Math.min(scene.width / width, scene.height / height)
            anchors.centerIn: parent

            Loader {
                anchors.fill: parent
                active: window.travel > 0
                opacity: window.fold
                sourceComponent: Widgets.OffcutWallpaper {
                    fluid: false
                    darkStock: true
                    family: window.displayFamily
                }
            }
            Loader {
                objectName: "desktopClock"
                x: 170; y: 105.5; width: 780; height: 209
                active: window.travel > 0 && !window.occupied
                opacity: Math.max(0, Math.min(1, (window.fold - .17) / .68))
                sourceComponent: Widgets.DayIndex {
                    dayFamily: window.displayFamily
                    FontLoader { id: body; source: window.fonts + "Poppins.ttf" }
                    detailFamily: body.status === FontLoader.Ready ? body.name
                                  : Qt.fontFamilies().includes("Poppins") ? "Poppins" : "DejaVu Sans"
                    dateInFlight: !window.landed
                }
            }
            Loader {
                objectName: "bootLog"
                anchors.fill: parent
                active: !window.landed
                opacity: Math.max(0, 1 - 3 * window.fold)
                sourceComponent: Item {
                    Rectangle { x: 148; y: 174; width: 824; height: 258; color: "#20232a" }
                    Repeater {
                        model: window.lineIndex
                        Item {
                            required property int index
                            x: 592; y: 198 + 54 * index; width: 363; height: 48
                            Text {
                                x: 21; anchors.verticalCenter: parent.verticalCenter
                                text: window.starts[parent.index] + " ms"
                                font.family: "JetBrains Mono"; font.pixelSize: 14; color: "#aeb5bd"
                            }
                            Text {
                                x: 116; anchors.verticalCenter: parent.verticalCenter
                                text: window.lines[parent.index]
                                font.family: "Roboto Condensed"; font.pixelSize: 21; color: "#f2efdf"
                            }
                        }
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom; anchors.bottomMargin: 36
                        text: "Press any key to skip"
                        font.family: "Roboto Condensed"; font.pixelSize: 15; color: "#aeb5bd"
                    }
                }
            }

            Loader {
                objectName: "wedge"
                active: !window.occupied || !window.landed
                readonly property real position: window.occupied ? 0 : window.fold
                x: 148 + (213 - 148) * position
                y: 150 + (115.5 - 150) * position
                width: 425 + (56 - 425) * position
                height: width * 306 / 425
                opacity: window.occupied ? 1 - window.fold : 1
                sourceComponent: PressMark { progress: window.impression; line: window.lineIndex }
            }

            Loader {
                objectName: "travellingTab"
                active: !window.landed
                readonly property real position: window.occupied ? 0 : window.fold
                readonly property real rowY: 198 + 54 * window.lineIndex
                x: 592 + (294 - 592) * position
                y: rowY + (255.5 - rowY) * position
                width: 363 + (144 - 363) * position
                height: 48 + (33 - 48) * position
                opacity: window.occupied ? 1 - window.fold : 1
                sourceComponent: Item {
                    id: tab
                    clip: true
                    Canvas {
                        anchors.fill: parent
                        onWidthChanged: requestPaint()
                        onHeightChanged: requestPaint()
                        onPaint: {
                            const c = getContext("2d");
                            c.reset();
                            const inset = height * .21;
                            c.fillStyle = "#f2efdf";
                            c.beginPath(); c.moveTo(inset, 3); c.lineTo(width, 3);
                            c.lineTo(width - inset, height - 3); c.lineTo(1, height - 3);
                            c.closePath(); c.fill();
                            c.fillStyle = window.fold < .5 ? "#ffd064" : "#f2efdf";
                            c.fillRect(inset, 0, width - inset, 1);
                            c.fillRect(0, height - 1, width - inset, 1);
                        }
                    }
                    Row {
                        x: 21; anchors.verticalCenter: parent.verticalCenter
                        opacity: Math.max(0, 1 - 3 * window.fold)
                        Text {
                            width: 95; anchors.verticalCenter: parent.verticalCenter
                            text: window.starts[window.lineIndex] + " ms"
                            font.family: "JetBrains Mono"; font.pixelSize: 14; color: "#20232a"
                        }
                        Text {
                            text: window.lines[window.lineIndex].slice(0, window.letters)
                            font.family: "Roboto Condensed"; font.bold: true; font.pixelSize: 26; color: "#20232a"
                        }
                    }
                    FontLoader { id: tabFont; source: window.fonts + "Poppins.ttf" }
                    Text {
                        anchors.centerIn: parent
                        opacity: Math.max(0, Math.min(1, 3 * window.fold - 1))
                        text: "18 SEP 2030"
                        font.family: tabFont.status === FontLoader.Ready ? tabFont.name : "DejaVu Sans"
                        font.weight: Font.DemiBold; font.pixelSize: 16; color: "#20232a"
                    }
                }
            }
        }
    }

    NumberAnimation {
        id: play
        target: window; property: "elapsed"; from: 0; to: 1500; duration: 1500
        running: !window.exporting && !window.reduced && !window.args.includes("--at")
    }
    Timer {
        running: window.exporting
        interval: 130
        onTriggered: {
            const out = window.args[window.args.indexOf("--out") + 1];
            scene.grabToImage(result => Qt.exit(result.saveToFile(out) ? 0 : 1));
        }
    }
}
