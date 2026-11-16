import qs.view.ui
import qs.view.cues
import QtQuick
import QtQuick.Controls

// One notification in the Inbox's sky (Z210), centred on its x, y: a head, and while unread a tail trailing back
// along the house angle with a glow. Urgent ones burn warm. The selected one is bigger. Its app is named under it.
// A click selects it for the reading panel.
AbstractButton {
    id: root
    required property string app
    required property string summary
    property bool unread: false
    property bool urgent: false
    property bool chosen: false
    readonly property color tone: urgent ? Design.warm : unread ? Design.coldStar : Design.line
    readonly property real head: chosen ? 18 : unread ? 12 : 8
    readonly property real tail: unread ? 70 : 0
    x: -width / 2
    y: -height / 2
    width: 44
    height: 44
    hoverEnabled: true
    focusPolicy: Qt.StrongFocus
    Accessible.name: app + ", " + summary + (unread ? ", unread" : "") + (urgent ? ", urgent" : "")
    onClicked: Feedback.play("ui.click")
    background: Item {
        // The tail: a fading streak back along the house angle (78°'s run, rising to the right).
        Rectangle {
            visible: root.tail > 0
            anchors.right: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            width: root.tail
            height: 2
            transformOrigin: Item.Right
            rotation: -12
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: "transparent" }
                GradientStop { position: 1; color: root.tone }
            }
        }
        Rectangle {
            visible: root.unread
            anchors.centerIn: parent
            width: root.head * 2.4
            height: width
            radius: width / 2
            color: Qt.alpha(root.tone, 0.16)
        }
        Rectangle {
            anchors.centerIn: parent
            width: root.head
            height: width
            radius: width / 2
            color: root.tone
            border.width: root.hovered || root.activeFocus ? 2 : 0
            border.color: Design.ink
        }
    }
    contentItem: Item {
        FText {
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height / 2 + root.head / 2 + 8
            text: root.app
            technical: true
            color: root.unread || root.chosen ? Design.ink : Design.faint
        }
    }
}
