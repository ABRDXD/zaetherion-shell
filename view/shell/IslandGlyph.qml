import QtQuick
import QtQuick.Controls
import qs.view.ui

AbstractButton {
    id: root
    required property string glyph
    required property string description
    property bool signalDot: false
    property url imageSource
    implicitWidth: Design.minHit
    implicitHeight: Design.minHit
    padding: 0
    hoverEnabled: true
    focusPolicy: Qt.StrongFocus
    Accessible.name: description
    Keys.onReturnPressed: clicked()
    Keys.onEnterPressed: clicked()

    // Keyboard focus is the sheet's inversion (an ink plane at 78°); hover is a quiet paper plane.
    background: Plane {
        id: plate
        z: -1   // Plane sets its own z, which would lift it over the glyph.
        role: root.activeFocus || root.down ? "ink" : root.hovered ? "paper" : "clear"
        slant: 3
    }

    contentItem: Item {
        MaterialSymbol {
            anchors.fill: parent
            text: root.glyph
            iconSize: Design.readout
            color: plate.textColor
            visible: image.status !== Image.Ready
        }
        Image {
            id: image
            anchors.centerIn: parent
            width: Design.control
            height: width
            source: root.imageSource
            sourceSize.width: width
            sourceSize.height: height
        }
        Rectangle {
            visible: root.signalDot
            anchors.right: parent.right
            anchors.top: parent.top
            width: Design.baseline
            height: width
            radius: width / 2
            color: Design.accent
        }
    }
}
