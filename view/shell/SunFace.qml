import qs.view.ui
import QtQuick

// The face of a system's sun (SpaceSystem): the room's number and name on top, one reading large, one
// line under it. It sits in the sun's content, whose `ink` and `run` it reads.
Item {
    id: root
    property string title: ""
    property string value: ""
    property string footer: ""
    // The footer carries an alarm (late, done): inverted into a tag, stated, not scolded, as the faces do.
    property bool alarm: false
    readonly property color ink: parent ? parent.ink : Design.ink
    readonly property color fill: parent ? parent.fill : Design.background
    readonly property real run: parent ? parent.run : 0
    anchors.fill: parent
    FText {
        x: root.run + 8
        y: 5
        width: parent.width - x - 8
        text: root.title
        technical: true
        font.weight: Font.Bold
        color: root.ink
    }
    FText {
        x: root.run / 2 + 8
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: 1
        width: parent.width - x - 10
        horizontalAlignment: Text.AlignHCenter
        text: root.value
        headline: true
        font.pixelSize: Design.readout
        font.weight: Font.Black
        fontSizeMode: Text.HorizontalFit
        minimumPixelSize: 9
        color: root.ink
    }
    Rectangle {
        visible: root.alarm
        x: footerText.x - 4
        y: footerText.y - 1
        width: Math.min(footerText.implicitWidth, footerText.width) + 8
        height: footerText.height + 2
        color: root.ink
    }
    FText {
        id: footerText
        x: 9
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 5
        width: parent.width - 18 - root.run
        text: root.footer
        technical: true
        font.weight: root.alarm ? Font.Bold : Font.Normal
        elide: Text.ElideRight
        color: root.alarm ? root.fill : root.ink
        opacity: root.alarm ? 1 : 0.8
    }
}
