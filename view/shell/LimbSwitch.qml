import QtQuick
import QtQuick.Controls
import qs.view.fluid
import qs.view.ui

AbstractButton {
    id: root
    required property string label
    required property bool selected
    implicitWidth: status.implicitWidth + 58
    implicitHeight: FluidTokens.controlHeight
    Accessible.role: Accessible.CheckBox
    Accessible.name: label
    Accessible.checked: selected
    onClicked: Feedback.play("ui.switch")
    background: Item {}
    contentItem: Row {
        spacing: 8
        FluidText {
            id: status
            anchors.verticalCenter: parent.verticalCenter
            text: !root.enabled ? "Offline" : root.selected ? "On" : "Off"
        }
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 44; height: 26; radius: height / 2
            color: root.selected ? FluidTokens.accent : FluidTokens.control
            border.width: root.visualFocus || !root.selected ? 1 : 0
            border.color: FluidTokens.ink
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                x: root.selected ? parent.width - width - 4 : 4
                width: 18; height: width; radius: width / 2
                color: root.selected ? FluidTokens.base : FluidTokens.secondary
            }
        }
    }
}
