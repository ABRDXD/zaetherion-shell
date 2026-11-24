pragma ComponentBehavior: Bound
import QtQuick

Item {
    id: face
    required property bool fluid
    required property string dayFamily
    required property string detailFamily

    Text {
        id: day
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -14
        text: "WEDNESDAY"
        font.family: face.dayFamily
        font.pixelSize: 82
        font.letterSpacing: 15
        color: face.fluid ? "#30294d" : "#41232b"
    }
    Item {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: day.bottom
        anchors.topMargin: 5
        width: face.fluid ? date.implicitWidth + 30 + time.implicitWidth : day.implicitWidth - 18
        Text {
            id: date
            text: face.fluid ? "18 September 2030" : "18 SEP 2030"
            font.family: face.detailFamily
            font.pixelSize: 18
            font.letterSpacing: face.fluid ? 0 : 1.5
            color: day.color
        }
        Text {
            id: time
            anchors.right: parent.right
            text: "– 07:24 –"
            font.family: face.detailFamily
            font.pixelSize: 18
            color: day.color
        }
    }
}
