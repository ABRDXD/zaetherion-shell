pragma ComponentBehavior: Bound
import QtQuick

Item {
    id: page
    required property bool fluid
    required property color ground
    required property string line

    Text {
        id: letter
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.horizontalCenterOffset: -parent.width * .075
        anchors.verticalCenter: parent.verticalCenter
        text: "Æ"
        color: page.fluid ? "#8791ad" : "#b77664"
        font.family: page.fluid ? "DejaVu Serif" : "DejaVu Sans"
        font.weight: Font.Bold
        font.pixelSize: Math.round(parent.height * .90)
    }
    Rectangle {
        // A single line of the fixture log takes the place of the crossbar.
        x: 0
        y: Math.round(parent.height * .48)
        width: parent.width
        height: 49
        color: page.ground
        Text {
            x: Math.round(page.width * .40)
            anchors.verticalCenter: parent.verticalCenter
            text: page.line
            font.family: page.fluid ? "Noto Sans" : "DejaVu Sans Mono"
            font.pixelSize: 25 // scale: study fixture, the mock's size
            font.weight: Font.Medium
            color: "#f3ede4"
        }
    }
}
