import qs.view.ui
import qs.view.cues
import QtQuick
import QtQuick.Controls

// One desk on the Workspaces orbit (Z209), centred on its x, y. An occupied desk is lit from the side facing
// the ring's centre in its star colour, glowing more the nearer it is; an empty one is a dark disc with a cold
// rim, and a desk the session remembers (emptied today) keeps a faint dashed shell. Hover asks to look
// (`look(true)`, then `look(false)`), a click goes there. The number sits under it except at the front,
// where the room's headline names it.
AbstractButton {
    id: root
    required property int number
    required property int windows
    property real size: 12
    property real depth: 1
    property bool front: false
    property bool current: false
    property bool remembered: false
    property bool litRight: false
    // The star colour of an occupied desk; ignored when empty.
    property color star: Design.coldStar
    // Near enough to the front for a larger number.
    readonly property bool near: depth > 0.6
    signal look(bool on)
    readonly property bool occupied: windows > 0
    readonly property color body: occupied ? Qt.tint(Design.coldBody, Qt.alpha(star, 0.07)) : Design.coldBody
    x: -width / 2
    y: -height / 2
    width: Math.max(size, 44)
    height: Math.max(size, 44)
    hoverEnabled: true
    focusPolicy: Qt.StrongFocus
    Accessible.name: "Desk " + number + ", " + windows + (windows === 1 ? " window" : " windows") + (current ? ", current" : "")
    onHoveredChanged: look(hovered)
    onActiveFocusChanged: look(activeFocus)
    onClicked: Feedback.play("ui.click")
    background: Item {
        // Glow, only for an occupied desk; brighter in front.
        Rectangle {
            visible: root.occupied
            anchors.centerIn: parent
            width: root.size * (root.front ? 1.6 : 1.5)
            height: width
            radius: width / 2
            color: Qt.alpha(root.star, root.front ? 0.07 : 0.04 + 0.05 * root.depth)
        }
        Rectangle {
            visible: root.remembered && !root.occupied
            anchors.centerIn: parent
            width: root.size + 10
            height: width
            radius: width / 2
            color: "transparent"
            border.width: 1
            border.color: Qt.alpha(Design.coldRim, 0.35)
        }
        Rectangle {
            id: disc
            anchors.centerIn: parent
            width: root.size
            height: root.size
            radius: root.size / 2
            border.width: root.hovered || root.activeFocus ? 2 : 1
            border.color: root.hovered || root.activeFocus ? Design.ink
                : Qt.alpha(root.occupied ? root.star : Design.coldRim, root.occupied ? 0.45 : 0.18 + 0.2 * root.depth)
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: root.litRight ? root.body : root.occupied ? root.star : Qt.alpha(Design.coldRim, 0.35) }
                GradientStop { position: root.litRight ? 0.62 : 0.38; color: root.body }
                GradientStop { position: 1; color: root.litRight ? (root.occupied ? root.star : Qt.alpha(Design.coldRim, 0.35)) : root.body }
            }
        }
        // The current desk keeps a signal mark under it, whatever is inspected.
        Rectangle {
            visible: root.current && !root.front
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: disc.bottom
            anchors.topMargin: 4
            width: 14
            height: 2
            color: Design.accent
        }
    }
    contentItem: Item {
        FText {
            visible: !root.front
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height / 2 + root.size / 2 + 8
            text: String(root.number).padStart(2, "0")
            headline: true
            font.weight: Font.Black
            font.pixelSize: root.near ? Design.readout : Design.control
            color: root.occupied || root.current ? Design.ink : Design.faint
        }
    }
}
