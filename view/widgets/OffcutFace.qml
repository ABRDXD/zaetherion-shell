pragma ComponentBehavior: Bound
import QtQuick
import "ClockWords.js" as Words

// The Fluid desktop clock: Astra's Offcut (tools/widget-study/OffcutClock.qml, kept for Fluid 23 Nov), the full
// Anurati weekday over the written date and the time, on a 780 × 209 sheet that the caller scales.
Item {
    id: face
    required property string dayFamily
    required property string detailFamily
    required property date now
    property var settings: ({})
    readonly property int trackingOffset: Words.tracking(settings.spacing)
    readonly property bool briefDate: settings.date === "short"
    readonly property color typeInk: Words.ink(settings.ink, true)
    readonly property int daySize: 82
    readonly property int detailSize: 18
    implicitWidth: 780
    implicitHeight: 209

    Item {
        id: sheet
        width: 780
        height: 209
        anchors.centerIn: parent
        scale: Math.min(face.width / width, face.height / height)
        Text {
            id: day
            objectName: "weekday"
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -14
            text: Words.weekday(face.now)
            font.family: face.dayFamily
            font.pixelSize: face.daySize
            font.letterSpacing: 15 + face.trackingOffset
            color: face.typeInk
        }
        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: day.bottom
            anchors.topMargin: 5
            width: date.implicitWidth + 30 + time.implicitWidth
            Text {
                id: date
                objectName: "todayDate"
                text: Words.dateLabel(face.now, true, face.briefDate)
                font.family: face.detailFamily
                font.pixelSize: face.detailSize
                color: day.color
            }
            Text {
                id: time
                objectName: "timeLabel"
                anchors.right: parent.right
                text: Words.timeLabel(face.now, face.settings.hours === 12 ? 12 : 24)
                font.family: face.detailFamily
                font.pixelSize: face.detailSize
                color: day.color
            }
        }
    }
}
