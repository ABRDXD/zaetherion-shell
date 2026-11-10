import qs.view.ui
import QtQuick
import QtQuick.Controls

// A link's toggle as a whole plane (Devices, MONTAGE §5): on, it is filled with signal (an
// accent-filled tile); off, paper. One click toggles. It names the link at readout size in Black,
// then what it is connected to and one detail.
AbstractButton {
    id: root
    property string symbol: ""
    property string label: ""
    property string line: ""
    property string detail: ""
    property bool on: false
    // The network letterpress (Letterpress, atlas #73): −1 deboss … 1 emboss, pressed into the label. 0 in Silent.
    property real press: 0
    readonly property color inkColor: on ? plane.textColor : Design.ink
    // The content is laid out for 104 px and centred in a taller plane.
    readonly property real inset: Math.max(0, (height - 104) / 2)
    implicitHeight: 104
    implicitWidth: 260
    hoverEnabled: true
    opacity: enabled ? 1 : 0.45
    Accessible.name: label + (on ? ", on" : ", off")
    Accessible.role: Accessible.CheckBox
    Accessible.checked: on
    onClicked: Feedback.play("ui.switch")
    background: Item {
        Plane {
            id: plane
            anchors.fill: parent
            role: root.on ? "signal" : "paper"
            slant: 3
            opacity: root.on || root.hovered ? 1 : 0.85
        }
        // Keyboard focus: an ink rule along the foot, inside the slant.
        Rectangle {
            visible: root.activeFocus
            x: 18
            y: parent.height - 7
            width: parent.width - 36
            height: 2
            color: root.inkColor
        }
    }
    contentItem: Item {
        MaterialSymbol {
            x: 26
            y: 14 + root.inset
            text: root.symbol
            iconSize: 22
            color: root.inkColor
        }
        FText {
            anchors.right: parent.right
            anchors.rightMargin: 24
            y: 18 + root.inset
            text: root.on ? "ON" : "OFF"
            technical: true
            font.letterSpacing: 2
            color: root.inkColor
        }
        FText {
            x: 22
            y: 42 + root.inset
            width: parent.width - 44
            text: root.label
            headline: true
            font.pixelSize: Design.readout
            font.weight: Font.Black
            color: root.inkColor
            // The impression: a light edge and a dark edge a pixel or two either side, swapped between the two.
            FText {
                z: -1
                visible: root.press !== 0
                x: (root.press > 0 ? -1 : 1) * Math.abs(root.press) * 1.6
                y: x
                width: parent.width
                text: parent.text
                font: parent.font
                color: Qt.rgba(1, 1, 1, 0.55)
            }
            FText {
                z: -1
                visible: root.press !== 0
                x: (root.press > 0 ? 1 : -1) * Math.abs(root.press) * 1.6
                y: x
                width: parent.width
                text: parent.text
                font: parent.font
                color: Qt.rgba(0, 0, 0, 0.4)
            }
        }
        FText {
            x: 18
            y: 68 + root.inset
            width: parent.width - 40
            text: root.line + (root.detail ? "  ·  " + root.detail : "")
            technical: true
            color: root.inkColor
            opacity: root.on ? 0.85 : 0.7
        }
    }
}
