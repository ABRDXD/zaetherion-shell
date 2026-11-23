pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
import QtCore

Window {
    id: window
    width: 1120
    height: 630
    visible: true
    title: "Modern Clock study"
    readonly property var args: Qt.application.arguments
    readonly property bool fluid: args.includes("--fluid")
    readonly property bool offcut: !args.includes("--open") && !inset
    readonly property bool inset: args.includes("--folio")
    property bool occupied: args.includes("--occupied")
    readonly property color paper: "#f5f2e9"
    readonly property color accent: fluid ? "#bddfdb" : "#ebc290"

    // Type samples may be read from the plugin on this machine. No font is bundled.
    readonly property url fontDir: StandardPaths.writableLocation(StandardPaths.HomeLocation)
                                          + "/.config/dms/plugins/modernClock/fonts/"
    Item {
        id: scene
        anchors.fill: parent
        focus: true
        Keys.onSpacePressed: window.occupied = !window.occupied
        Loader {
            anchors.fill: parent
            sourceComponent: window.offcut ? specimen : sky
            Component { id: sky; StudySky {} }
            Component {
                id: specimen
                OffcutWallpaper {
                    fluid: window.fluid
                    FontLoader { id: specimenFont; source: window.fontDir + "Anurati.otf" }
                    family: specimenFont.status === FontLoader.Ready ? specimenFont.name : "DejaVu Sans"
                }
            }
        }

        Loader {
            id: clock
            active: !window.occupied
            width: Math.min(scene.width - 32, 780)
            height: 209
            x: (scene.width - width) / 2
            y: scene.height / 3 - height / 2

            sourceComponent: Item {
                function face(loader, family) {
                    if (loader.status === FontLoader.Ready) return loader.name;
                    return Qt.fontFamilies().includes(family) ? family : "DejaVu Sans";
                }
                id: facePlate
                FontLoader { id: dayFace; source: window.fontDir + "Anurati.otf" }
                FontLoader { id: bodyFace; source: window.fontDir + "Poppins.ttf" }

                Rectangle {
                    anchors.fill: parent
                    visible: window.inset
                    color: window.fluid ? "#e01a292d" : "#ee202831"
                    radius: window.fluid ? 42 : 0
                    border.width: 1
                    border.color: window.fluid ? "#667b7d" : "#757572"
                }

                // The two marks register the baseline against the edges of the dark plane.
                Repeater {
                    model: window.inset ? 2 : 0
                    Rectangle {
                        required property int index
                        width: window.fluid ? 5 : 22
                        height: window.fluid ? width : 2
                        radius: window.fluid ? width / 2 : 0
                        x: index ? clock.width - width - 21 : 21
                        y: clock.height / 2
                        color: window.accent
                    }
                }

                Loader {
                    anchors.fill: parent
                    active: window.offcut
                    sourceComponent: OffcutClock {
                        fluid: window.fluid
                        dayFamily: facePlate.face(dayFace, "Anurati")
                        detailFamily: facePlate.face(bodyFace, "Poppins")
                    }
                }
                Column {
                    visible: !window.offcut
                    anchors.centerIn: parent
                    spacing: window.inset ? 5 : 4
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "WEDNESDAY"
                        color: window.paper
                        font.family: facePlate.face(dayFace, "Anurati")
                        font.pixelSize: window.inset ? 64 : 72
                        font.letterSpacing: window.inset ? 13 : 17
                    }
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: window.inset
                        width: 208
                        height: 1
                        color: window.fluid ? "#556f71" : "#6c6254"
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        id: dateLine
                        Repeater {
                            model: !window.inset && !window.fluid ? 2 : 0
                            Rectangle {
                                required property int index
                                anchors.verticalCenter: parent.verticalCenter
                                x: index ? dateLine.width + 14 : -width - 14
                                width: 28
                                height: 1
                                color: window.accent
                            }
                        }
                        text: "18 SEP 2030"
                        color: window.inset ? window.paper : window.accent
                        font.family: facePlate.face(bodyFace, "Poppins")
                        font.pixelSize: 19
                        font.letterSpacing: 3
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "– 07:24 AM –"
                        color: window.inset ? window.accent : window.paper
                        font.family: facePlate.face(bodyFace, "Poppins")
                        font.pixelSize: 19
                        font.letterSpacing: 3
                    }
                }
            }
        }
    }

    Timer {
        interval: 180
        running: window.args.includes("--out")
        onTriggered: {
            const path = window.args[window.args.indexOf("--out") + 1];
            scene.grabToImage(result => Qt.exit(result.saveToFile(path) ? 0 : 1));
        }
    }
}
