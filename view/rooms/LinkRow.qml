import qs.view.ui
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// One ruled line of Devices' link panel: a network or a paired device. The whole line is the button;
// `verb` says what a click does. `strength` (0–1) draws four rising blades; −1 draws none.
AbstractButton {
    id: root
    property string label: ""
    property string tag: ""
    property string verb: ""
    property bool current: false
    property bool secured: false
    property real strength: -1
    // Phantom ports (atlas #23): a device linked when last seen and not now. `left` still listed (a click links it
    // again), `gone` vanished from the list: an empty socket, inert. Both show when, for this session only.
    property double lost: 0
    property bool gone: false
    implicitHeight: 44
    hoverEnabled: true
    opacity: enabled ? 1 : 0.45
    Accessible.name: (verb ? verb + ": " : "") + label + (tag ? ", " + tag : "")
    onClicked: Feedback.play("ui.click")
    background: Item {
        Plane {
            anchors.fill: parent
            anchors.bottomMargin: 3
            role: root.hovered || root.activeFocus ? "paper" : "clear"
            slant: 3
        }
        Hairline {
            anchors.bottom: parent.bottom
            width: parent.width
            node: 3
            color: root.current ? Design.accent : Design.line
        }
        // The empty socket where a gone device was: a dashed outline in the line's place.
        Rectangle {
            visible: root.gone
            anchors.fill: parent
            anchors.bottomMargin: 6
            anchors.topMargin: 3
            color: "transparent"
            border.width: 1
            border.color: Design.line
            opacity: 0.8
        }
    }
    contentItem: RowLayout {
        spacing: 8
        Item {
            visible: root.strength >= 0
            implicitWidth: 22
            implicitHeight: 14
            Repeater {
                model: 4
                Rectangle {
                    required property int index
                    x: index * 5
                    width: 3
                    height: 4 + index * 3.3
                    y: parent.height - height
                    color: index < Math.ceil(root.strength * 4) ? (root.current ? Design.accent : Design.ink) : Design.line
                    transform: Matrix4x4 { matrix: Qt.matrix4x4(1, Design.shear, 0, -Design.shear * height, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1) }
                }
            }
        }
        FText {
            Layout.fillWidth: true
            text: root.label
            headline: true
            font.capitalization: Font.MixedCase
            font.pixelSize: Design.readout
            font.letterSpacing: -0.2
            font.weight: root.current ? Font.DemiBold : Font.Normal
            color: root.current ? Design.accent : Design.ink
        }
        MaterialSymbol {
            visible: root.secured
            text: "lock"
            iconSize: 14
            color: Design.faint
        }
        FText {
            visible: root.lost > 0
            text: (root.gone ? "GONE " : "LEFT ") + Qt.formatTime(new Date(root.lost), "HH:mm")
            technical: true
            color: Design.faint
        }
        FText {
            visible: root.tag !== ""
            text: root.tag
            technical: true
            color: root.current ? Design.accent : Design.muted
        }
        FText {
            visible: root.verb !== "" && (root.hovered || root.activeFocus)
            text: "→ " + root.verb
            technical: true
            color: Design.ink
        }
    }
}
