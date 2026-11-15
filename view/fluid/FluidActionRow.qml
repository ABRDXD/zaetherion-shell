import QtQuick
import QtQuick.Controls

// A shared action on the continuous surface; separators carry the grouping.
Button {
    id: root
    property string detail: ""
    implicitHeight: FluidTokens.controlHeight
    implicitWidth: title.implicitWidth + note.implicitWidth + FluidTokens.gap * 2
    Accessible.name: text + (detail ? ", " + detail : "")
    hoverEnabled: true
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
