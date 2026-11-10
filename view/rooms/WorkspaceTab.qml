import qs.view.ui
import QtQuick
import QtQuick.Controls

// One plane of Workspaces' stack: its number, a blade per window (up to six), and HERE on the current
// one. Inspected, it is inverted ink. Hover asks to look (`look(true)`, then `look(false)` when it ends), never
// keyboard focus: a look replaces the window list, and the keyboard has to be able to reach it. A click goes there.
// Rectangles and text only (MONTAGE §8: no Shapes, no Canvas in this room).
AbstractButton {
    id: root
    required property int number
    required property int windows
    property bool remembered: false
    property bool current: false
    property bool inspected: false
    signal look(bool on)
    readonly property color inkColor: inspected ? plane.textColor : current ? Design.ink : Design.muted
    implicitHeight: 38
    hoverEnabled: true
    Accessible.name: "Workspace " + number + ", " + windows + (windows === 1 ? " window" : " windows") + (current ? ", current" : "")
    onHoveredChanged: look(hovered)
    onClicked: Feedback.play("ui.click")
    background: Item {
        Plane {
            id: plane
            anchors.fill: parent
            anchors.topMargin: 2
            anchors.bottomMargin: 2
            role: root.inspected ? "ink" : root.hovered ? "paper" : "clear"
            slant: 3
        }
        // The current workspace keeps a signal edge whatever is inspected.
        Rectangle {
            visible: root.current
            x: 2
            y: 4
            width: 3
            height: parent.height - 8
            color: Design.accent
        }
        Rectangle {
            visible: root.activeFocus && !root.inspected
            x: 14
            y: parent.height - 5
            width: parent.width - 28
            height: 1
            color: Design.ink
        }
    }
    contentItem: Item {
        FText {
            x: 16
            anchors.verticalCenter: parent.verticalCenter
            text: String(root.number).padStart(2, "0")
            headline: true
            font.pixelSize: Design.readout
            font.weight: root.inspected || root.current ? Font.Black : Font.Normal
            color: root.inkColor
        }
        Row {
            x: 52
            anchors.verticalCenter: parent.verticalCenter
            spacing: 3
            Repeater {
                model: Math.min(6, root.windows)
                Rectangle {
                    width: 3
                    height: 12
                    color: root.inkColor
                    transform: Matrix4x4 { matrix: Qt.matrix4x4(1, Design.shear, 0, -Design.shear * 12, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1) }
                }
            }
        }
        FText {
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            text: root.current ? "HERE" : root.windows ? String(root.windows).padStart(2, "0") : root.remembered ? "GHOST" : "—"
            technical: true
            color: root.current && !root.inspected ? Design.accent : root.inkColor
        }
    }
}
