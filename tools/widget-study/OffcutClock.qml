pragma ComponentBehavior: Bound
import QtQuick

Item {
    id: face
    required property bool fluid
    required property string dayFamily
    required property string detailFamily
    property int trackingOffset: 0
    property bool briefDate: false
    property color typeInk: fluid ? "#30294d" : "#41232b"
    property string timeLabel: "– 07:24 –"

    Text {
        id: day
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -14
        text: "WEDNESDAY"
        font.family: face.dayFamily
        font.pixelSize: 82 // scale: study fixture, the mock's size
        font.letterSpacing: 15 + face.trackingOffset
        color: face.typeInk
    }
    Item {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: day.bottom
        anchors.topMargin: 5
        width: face.fluid ? date.implicitWidth + 30 + time.implicitWidth : day.implicitWidth - 18
        Text {
            id: date
            text: face.briefDate ? "18 Sep" : face.fluid ? "18 September 2030" : "18 SEP 2030"
            font.family: face.detailFamily
            font.pixelSize: 18 // scale: study fixture, the mock's size
            font.letterSpacing: face.fluid ? 0 : 1.5
            color: day.color
        }
        Text {
            id: time
            anchors.right: parent.right
            text: face.timeLabel
            font.family: face.detailFamily
            font.pixelSize: 18 // scale: study fixture, the mock's size
            color: day.color
        }
    }
}
