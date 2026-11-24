pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.view.ui

// The desktop clock (Z46, Z85): Day index in Angular, Offcut in Fluid, sized by its box. Anurati and Poppins come
// from the Modern Clock plugin the owner installed (~/.config/dms/plugins/modernClock/fonts/); none is bundled
// (Anurati is for personal use only). Without them the face falls back to the shell's sans.
Item {
    id: root
    property var face: ({})
    property date now: Clock.date
    property bool fluid: Design.fluid
    // The login (Z55) drives these; at rest they are settled.
    property real leftPull: 1
    property real rightPull: 1
    property bool dateInFlight: false
    property bool stamp: true
    readonly property url fontDir: "file://" + (Quickshell.env("HOME") ?? "") + "/.config/dms/plugins/modernClock/fonts/"
    readonly property string dayFamily: anurati.status === FontLoader.Ready ? anurati.name
        : Qt.fontFamilies().includes("Anurati") ? "Anurati" : Design.sans
    readonly property string detailFamily: poppins.status === FontLoader.Ready ? poppins.name
        : Qt.fontFamilies().includes("Poppins") ? "Poppins" : Design.sans
    readonly property Item faceItem: loader.item
    FontLoader { id: anurati; source: root.fontDir + "Anurati.otf" }
    FontLoader { id: poppins; source: root.fontDir + "Poppins.ttf" }
    Accessible.role: Accessible.StaticText
    Accessible.name: Qt.formatDateTime(root.now, "dddd d MMMM yyyy, HH:mm")

    Loader {
        id: loader
        anchors.fill: parent
        sourceComponent: root.fluid ? offcut : dayIndex
        Component {
            id: dayIndex
            DayIndexFace {
                dayFamily: root.dayFamily; detailFamily: root.detailFamily; now: root.now; face: root.face
                leftPull: root.leftPull; rightPull: root.rightPull; dateInFlight: root.dateInFlight; stamp: root.stamp
            }
        }
        Component {
            id: offcut
            OffcutFace { dayFamily: root.dayFamily; detailFamily: root.detailFamily; now: root.now; settings: root.face }
        }
    }
}
