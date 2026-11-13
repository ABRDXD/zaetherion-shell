import QtQuick
import QtQuick.Controls

Button {
    id: root
    property bool selected: false
    property bool primary: false
    implicitHeight: FluidTokens.controlHeight
    implicitWidth: label.implicitWidth + FluidTokens.gap * 2
    hoverEnabled: true
    Accessible.name: text
    Accessible.role: Accessible.Button
    Accessible.checkable: checkable
    Accessible.checked: selected
    opacity: enabled ? 1 : 0.5
    background: Rectangle {
        radius: FluidTokens.controlRadius
        color: root.primary ? FluidTokens.accent : root.hovered || root.down || root.selected ? FluidTokens.control : FluidTokens.base
        border.width: root.activeFocus ? 2 : 1
        border.color: root.activeFocus ? FluidTokens.ink : root.selected ? FluidTokens.accent : FluidTokens.rule
    }
    contentItem: FluidText {
        id: label
        text: root.text
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        color: root.primary ? FluidTokens.base : FluidTokens.ink
        elide: Text.ElideRight
    }
}
