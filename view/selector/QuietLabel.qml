import QtQuick
import qs.view.ui

// Pilot light on a screen the pointer isn't on: a small pause mark and one line, lower left.
Rectangle {
    id: root
    property string text: ""
    x: EclipseLook.quietMargin
    width: row.implicitWidth + 2 * EclipseLook.quietPadding
    height: EclipseLook.quietHeight
    color: EclipseLook.footer
    Row {
        id: row
        x: EclipseLook.quietPadding
        anchors.verticalCenter: parent.verticalCenter
        spacing: EclipseLook.pauseTextGap
        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: EclipseLook.pauseGap
            Repeater {
                model: 2
                Rectangle { width: EclipseLook.pauseBarWidth; height: EclipseLook.quietBarHeight; color: EclipseLook.lime }
            }
        }
        Text { text: root.text; color: EclipseLook.footerText; font.family: Design.mono; font.pixelSize: EclipseLook.quietText }
    }
}
