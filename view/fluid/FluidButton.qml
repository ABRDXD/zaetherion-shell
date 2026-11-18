import QtQuick
import QtQuick.Controls
import qs.view.ui
import "FluidKeys.js" as Keys_

Button {
    id: root
    property bool selected: false
    property bool primary: false
    implicitHeight: FluidTokens.controlHeight
    implicitWidth: label.implicitWidth + FluidTokens.gap * 2
    hoverEnabled: true
    // Radix-style focus: the ring is for the keyboard only (a click does not take focus), Enter presses as Space
    // does, and ←/→ move along a row of sibling controls.
    focusPolicy: Qt.TabFocus
    // The same acknowledgement as Angular's FButton: the host's click sound, through the core's gate (Feedback).
    onClicked: Feedback.play("ui.click")
    Keys.onReturnPressed: root.click()
    Keys.onEnterPressed: root.click()
    Keys.onLeftPressed: event => { const to = Keys_.sibling(root, -1); if (to) to.forceActiveFocus(Qt.TabFocusReason); else event.accepted = false; }
    Keys.onRightPressed: event => { const to = Keys_.sibling(root, 1); if (to) to.forceActiveFocus(Qt.TabFocusReason); else event.accepted = false; }
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
