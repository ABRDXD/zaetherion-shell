import QtQuick
import QtQuick.Controls
import qs.view.ui

AbstractButton {
    id: root
    required property string glyph
    required property string description
    property bool signalDot: false
    // A status indicator rather than an action: the muted role until hovered or focused, at the same size.
    property bool quiet: false
    property url imageSource
    implicitWidth: Design.minHit
    implicitHeight: Design.minHit
    padding: 0
    hoverEnabled: true
    focusPolicy: Qt.StrongFocus
    Accessible.name: description
    Keys.onReturnPressed: clicked()
    Keys.onEnterPressed: clicked()

    // Keyboard focus is the sheet's inversion (an ink plane at 78°, a rounded plate in Fluid); hover is paper.
    background: FPlate {
        id: plate
        z: -1
        role: root.activeFocus || root.down ? "ink" : root.hovered ? "paper" : "clear"
    }

    contentItem: Item {
        MaterialSymbol {
            anchors.fill: parent
            text: root.glyph
            iconSize: Design.statusIcon
            fill: Design.iconFill
            weight: Design.iconWeight
            color: root.quiet && plate.role === "clear" ? Design.muted : plate.textColor
            visible: image.status !== Image.Ready
        }
        Image {
            id: image
            anchors.centerIn: parent
            width: Design.smallIcon
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
