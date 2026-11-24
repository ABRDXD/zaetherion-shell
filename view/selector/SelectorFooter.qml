import QtQuick
import qs.view.ui

// Eclipse's dark footer: the frozen mark, the one instruction, and the way out.
Rectangle {
    id: root
    property string prompt: ""
    height: EclipseLook.footerHeight
    color: EclipseLook.footer

    Row {
        anchors.left: parent.left
        anchors.leftMargin: EclipseLook.footerMargin
        anchors.verticalCenter: parent.verticalCenter
        spacing: EclipseLook.pauseTextGap
        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: EclipseLook.pauseGap
            Repeater {
                model: 2
                Rectangle { width: EclipseLook.pauseBarWidth; height: EclipseLook.pauseBarHeight; color: EclipseLook.lime }
            }
        }
        Text { text: "Frozen screen"; color: EclipseLook.footerText; font.family: Design.mono; font.pixelSize: EclipseLook.footerSmall }
    }
    Text {
        anchors.centerIn: parent
        text: root.prompt
        color: EclipseLook.footerText
        font.family: Design.sans
        font.pixelSize: EclipseLook.footerPrompt
    }
    Text {
        anchors.right: parent.right
        anchors.rightMargin: EclipseLook.footerMargin
        anchors.verticalCenter: parent.verticalCenter
        text: "Esc Cancel"
        color: EclipseLook.footerText
        font.family: Design.mono
        font.pixelSize: EclipseLook.footerSmall
    }
}
