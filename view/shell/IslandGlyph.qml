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

    background: Rectangle {
        color: root.hovered || root.down || root.activeFocus ? Design.hover : "transparent"
        radius: Design.radiusControl
        border.width: root.activeFocus ? 1 : 0
        border.color: Design.accent
    }

    contentItem: Item {
        MaterialSymbol {
            anchors.fill: parent
            text: root.glyph
            iconSize: Design.readout
            color: Design.ink
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
