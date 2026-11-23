import QtQuick
import QtQuick.Controls

// A row of the sheet's menus (MONTAGE.md §4.4): a ruled line with a small square node and the label; hover,
// focus or press wipe it to ink and set the pointer beside it. `detail` is a right-aligned caption.
AbstractButton {
    id: root
    property string label: ""
    property string detail: ""
    readonly property bool lit: hovered || activeFocus || down
    implicitHeight: 30
    implicitWidth: 220
    hoverEnabled: true
    padding: 0
    opacity: enabled ? 1 : 0.45
    Accessible.name: label
    onClicked: Feedback.play("ui.click")
    background: Item {
        Rectangle {
            x: 16
            anchors.bottom: parent.bottom
            width: parent.width - 16
            height: 1
            color: Qt.alpha(Design.line, 0.7)
        }
        Wipe {
            id: wipe
            x: 16
            width: parent.width - 16
            height: parent.height
            scope: root
            on: root.lit
        }
    }
    contentItem: Item {
        Pointer {
            x: 1
            anchors.verticalCenter: parent.verticalCenter
            visible: root.lit
        }
        Rectangle {
            x: 26
            anchors.verticalCenter: parent.verticalCenter
            width: 5
            height: 5
            color: wipe.inverted ? wipe.ink : Design.accent
        }
        FText {
            x: 40
            width: parent.width - x - detailText.width - 12
            anchors.verticalCenter: parent.verticalCenter
            text: root.label
            font.pixelSize: Design.control
            color: wipe.ink
        }
        FText {
            id: detailText
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            visible: text !== ""
            text: root.detail
            technical: true
            color: wipe.inverted ? wipe.ink : Design.muted
        }
    }
    transform: Translate { y: root.down ? 1 : 0 }
}
