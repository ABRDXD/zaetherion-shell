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
    readonly property var starts: [0, 215, 445, 682]
    property var lines: ["fartd online", "island at rest",
                                  occupied ? "workspace occupied" : "workspace empty",
                                  occupied ? "widgets asleep" : "clock on desktop"]
    readonly property int lineIndex: elapsed < starts[1] ? 0 : elapsed < starts[2] ? 1 : elapsed < starts[3] ? 2 : 3
    readonly property int letters: Math.floor((elapsed - starts[lineIndex]) / 12)
    readonly property real impression: (lineIndex + Math.min(1, letters / lines[lineIndex].length)) / 4
    FoldMotion { id: cue; elapsed: window.elapsed }
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
                active: cue.cut > 0
                sourceComponent: Widgets.OffcutWallpaper {
                    fluid: false
                    darkStock: true
                    family: window.displayFamily
                }
            }
            Loader {
                objectName: "desktopClock"
                x: 170; y: 105.5; width: 780; height: 209
                active: cue.leftPull > 0 && !window.occupied
                sourceComponent: Widgets.DayIndex {
                    dayFamily: window.displayFamily
                    FontLoader { id: body; source: window.fonts + "Poppins.ttf" }
                    detailFamily: body.status === FontLoader.Ready ? body.name
                                  : Qt.fontFamilies().includes("Poppins") ? "Poppins" : "DejaVu Sans"
                    dateInFlight: !window.landed
                    leftPull: cue.leftPull
                    rightPull: cue.rightPull
                }
            }
            Loader {
                objectName: "bootLog"
                anchors.fill: parent
                active: cue.cut < 1
                sourceComponent: Item {
                    id: outgoing
                    readonly property real edge: (width + .21255656 * height) * (1 - cue.cut)
                    Canvas {
                        anchors.fill: parent
                        property real edge: outgoing.edge
                        onEdgeChanged: requestPaint()
                        onPaint: {
                            const c = getContext("2d");
                            c.reset();
                            c.save();
                            c.beginPath();
                            c.moveTo(0, 0); c.lineTo(edge, 0);
                            c.lineTo(edge - .21255656 * height, height); c.lineTo(0, height);
                            c.closePath(); c.clip();
                            c.fillStyle = window.color;
                            c.fillRect(0, 0, width, height);
                            c.fillStyle = "#20232a";
                            c.fillRect(148, 174 + 48 * cue.cut, 824, 258 - 96 * cue.cut);
                            c.restore();
                        }
                    }
                    Repeater {
                        model: window.lineIndex
                        Item {
                            required property int index
                            x: 592 + (3 - index) * 20 * cue.cut
                            y: 198 + 54 * index
                            width: Math.max(0, Math.min(363, outgoing.edge - .21255656 * (y + 24) - x))
                            height: 48
                            clip: true
                            Text {
                                x: 21; anchors.verticalCenter: parent.verticalCenter
                                text: window.starts[parent.index] + " ms"
                                font.family: "JetBrains Mono"; font.pixelSize: 14; color: "#aeb5bd" // scale: study fixture, the mock's size
                            }
                            Text {
                                x: 116; anchors.verticalCenter: parent.verticalCenter
                                text: window.lines[parent.index]
                                font.family: "Roboto Condensed"; font.pixelSize: 21; color: "#f2efdf" // scale: study fixture, the mock's size
                            }
                        }
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom; anchors.bottomMargin: 36
                        opacity: 1 - Math.min(1, 6 * cue.cut)
                        text: "Press any key to skip"
                        font.family: "Roboto Condensed"; font.pixelSize: 15; color: "#aeb5bd" // scale: study fixture, the mock's size
                    }
                }
            }

            Loader {
                objectName: "wedge"
                active: !window.occupied || !window.landed
                readonly property real position: window.occupied ? 0 : cue.strike
                readonly property real lift: window.occupied ? 0 : cue.lift * (1 - position)
                x: 148 + 65 * position + 5 * lift
                y: 150 - 34.5 * position - 24 * lift + 5 * cue.stamp
                width: 425 - 369 * position
                height: width * 306 / 425
                opacity: window.occupied ? 1 - cue.cut : 1
                sourceComponent: PressMark { progress: window.impression; line: window.lineIndex }
            }

            Loader {
                objectName: "travellingTab"
                active: !window.landed
                id: shuttle
                readonly property bool toClock: !window.occupied
                readonly property real sideways: toClock ? cue.throwTab : 0
                readonly property real upward: toClock ? cue.climb : 0
                readonly property real rowY: 198 + 54 * window.lineIndex
                // Break free to the right, sweep left, then take the last 21 px
                // along the 78° seam. Keep the fold centred on the moving band.
                x: 592 - 277 * sideways - 21 * upward + (toClock ? 12 * cue.unlock * (1 - sideways) : 0)
                width: 363 - 219 * sideways + (toClock ? 38 * cue.compression : 0)
                readonly property real faceHeight: 48 - 15 * upward
                height: faceHeight
                y: rowY - (rowY - 255.5) * upward + (toClock ? 3 * cue.contact : 0)
                opacity: toClock ? 1 : 1 - cue.cut
                transform: Scale {
                    origin.y: shuttle.height / 2
                    yScale: shuttle.toClock ? Math.max(.075, Math.abs(Math.cos(Math.PI * cue.turnover))) : 1
                }
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
                            c.fillStyle = cue.compression > .9 ? "#ffd064" : "#f2efdf";
                            c.beginPath(); c.moveTo(inset, 3); c.lineTo(width, 3);
                            c.lineTo(width - inset, height - 3); c.lineTo(1, height - 3);
                            c.closePath(); c.fill();
                            c.fillStyle = cue.turnover < .5 ? "#ffd064" : "#f2efdf";
                            c.fillRect(inset, 0, width - inset, 1);
                            c.fillRect(0, height - 1, width - inset, 1);
                        }
                    }
                    Row {
                        x: 21; anchors.verticalCenter: parent.verticalCenter
                        visible: !shuttle.toClock || cue.turnover < .5
                        Text {
                            width: 95; anchors.verticalCenter: parent.verticalCenter
                            text: window.starts[window.lineIndex] + " ms"
                            font.family: "JetBrains Mono"; font.pixelSize: 14; color: "#20232a" // scale: study fixture, the mock's size
                        }
                        Text {
                            text: window.lines[window.lineIndex].slice(0, window.letters)
                            font.family: "Roboto Condensed"; font.bold: true; font.pixelSize: 26; color: "#20232a" // scale: study fixture, the mock's size
                        }
                    }
                    FontLoader { id: tabFont; source: window.fonts + "Poppins.ttf" }
                    Text {
                        anchors.centerIn: parent
                        visible: shuttle.toClock && cue.turnover >= .5
                        text: "18 SEP 2030"
                        font.family: tabFont.status === FontLoader.Ready ? tabFont.name : "DejaVu Sans"
                        font.weight: Font.DemiBold; font.pixelSize: 16; color: "#20232a" // scale: study fixture, the mock's size
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
