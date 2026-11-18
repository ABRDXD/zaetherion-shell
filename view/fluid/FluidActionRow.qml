import QtQuick
import QtQuick.Controls
import qs.view.ui
import "FluidKeys.js" as Keys_

// A shared action on the continuous surface; separators carry the grouping.
Button {
    id: root
    property string detail: ""
    implicitHeight: FluidTokens.controlHeight
    implicitWidth: title.implicitWidth + note.implicitWidth + FluidTokens.gap * 2
    Accessible.name: text + (detail ? ", " + detail : "")
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
    Keys.onUpPressed: event => { const to = Keys_.along(root, false); if (to) to.forceActiveFocus(Qt.TabFocusReason); else event.accepted = false; }
    Keys.onDownPressed: event => { const to = Keys_.along(root, true); if (to) to.forceActiveFocus(Qt.TabFocusReason); else event.accepted = false; }
    opacity: enabled ? 1 : 0.5
    background: Rectangle {
        color: root.hovered || root.down ? FluidTokens.control : "transparent"
        radius: FluidTokens.controlRadius
        border.width: root.activeFocus ? 2 : 0
        border.color: FluidTokens.ink
    }
    contentItem: Item {
        FluidText {
            id: title
            anchors.left: parent.left
            anchors.right: note.left
            anchors.rightMargin: FluidTokens.gap
            anchors.verticalCenter: parent.verticalCenter
            text: root.text
            elide: Text.ElideRight
        }
        FluidText {
            id: note
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, parent.width * 0.45)
            text: root.detail
            color: FluidTokens.secondary
            font.pixelSize: FluidTokens.caption
            elide: Text.ElideRight
        }
    }
}
