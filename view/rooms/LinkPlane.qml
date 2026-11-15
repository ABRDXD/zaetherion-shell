import qs.view.ui
import qs.view.cues
import QtQuick
import QtQuick.Controls

// A link's toggle as a whole plane (Devices, MONTAGE §5): on, it is filled with signal (an
// accent-filled tile); off, paper. One click toggles; a right-click opens the link's own panel
// (secondaryClicked). It names the link at readout size in Black, then what it is connected to and one detail.
// Hovered, a settings glyph shows beside ON/OFF: the same panel for the left button, and the hint that the right
// button opens it too (owner, 15 November 2026).
AbstractButton {
    id: root
    signal secondaryClicked()
    property string symbol: ""
    property string label: ""
    property string line: ""
    property string detail: ""
    property bool on: false
    // What the settings glyph's hint names ("Wi-Fi settings"); empty: no glyph.
    property string settingsHint: ""
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
    // The right button only, so the left click stays the toggle.
    MouseArea {
        objectName: "linkSecondary"
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        onClicked: root.secondaryClicked()
    }
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
            id: state
            anchors.right: parent.right
            anchors.rightMargin: 24
            y: 18 + root.inset
            text: root.on ? "ON" : "OFF"
            technical: true
            font.letterSpacing: 2
            color: root.inkColor
        }
        // The settings glyph: shown while hovered (or focused), a left click opens the link's panel.
        MaterialSymbol {
            id: settingsGlyph
            objectName: "linkSettings"
            anchors.right: state.left
            anchors.rightMargin: Design.baseline * 3
            anchors.verticalCenter: state.verticalCenter
            visible: root.settingsHint !== "" && root.enabled
            opacity: root.hovered || root.activeFocus || settingsArea.containsMouse ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Motion.tint } }
            text: "tune"
            iconSize: 18
            color: root.inkColor
            MouseArea {
                id: settingsArea
                anchors.fill: parent
                anchors.margins: -Design.baseline * 2
                hoverEnabled: true
                enabled: settingsGlyph.opacity > 0
                cursorShape: Qt.PointingHandCursor
                onClicked: root.secondaryClicked()
            }
            ToolTip.visible: settingsArea.containsMouse
            ToolTip.delay: 400
            ToolTip.text: root.settingsHint + " · or right-click the tile"
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
