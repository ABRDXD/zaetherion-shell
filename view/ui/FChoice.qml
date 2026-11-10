import QtQuick
import QtQuick.Controls

ComboBox {
    id: root
    implicitHeight: 38
    implicitWidth: 120
    font.family: Design.mono
    font.features: ({ "tnum": 1 })
    font.pixelSize: Design.control
    font.italic: false
    font.styleName: "Regular"
    Accessible.name: displayText
    onActivated: Feedback.play("ui.switch")
    contentItem: FText {
        text: root.displayText
        verticalAlignment: Text.AlignVCenter
        leftPadding: 10
        rightPadding: 25
        color: wipe.ink
    }
    background: Item {
        FFrame {
            anchors.fill: parent
            fillColor: Design.surface
            lineColor: root.activeFocus ? Design.ink : Design.line
        }
        Wipe {
            id: wipe
            anchors.fill: parent
            scope: root
            on: root.hovered || root.pressed || root.popup.visible
            ruled: root.popup.visible
        }
    }
    indicator: FText {
        x: root.width - 20
        anchors.verticalCenter: parent.verticalCenter
        text: "⌄"
        font.pixelSize: Design.readout
        color: wipe.inverted ? wipe.ink : Design.muted
    }
    // The chosen row is inverted, with the pointer at its left.
    delegate: ItemDelegate {
        id: row
        width: root.width
        required property var modelData
        required property int index
        text: String(modelData)
        font: root.font
        contentItem: FText {
            text: row.text
            verticalAlignment: Text.AlignVCenter
            leftPadding: 18
            color: row.highlighted ? (Design.onInk ?? Design.background) : Design.ink
        }
        highlighted: root.highlightedIndex === index
        background: Rectangle {
            color: row.highlighted ? Design.ink : Design.surface
            radius: Design.radiusSmall
            Pointer {
                visible: row.highlighted
                x: 5
                anchors.verticalCenter: parent.verticalCenter
                width: 7
                height: 10
                color: Design.onInk ?? Design.background
            }
        }
    }
    popup: Popup {
        y: root.height
        width: root.width
        padding: 1
        background: Rectangle {
            color: Design.surface
            border.color: Design.line
            radius: Design.radiusControl
        }
        contentItem: ListView {
            implicitHeight: Math.min(180, contentHeight)
            model: root.popup.visible ? root.delegateModel : null
            clip: true
            currentIndex: root.highlightedIndex
            ScrollIndicator.vertical: ScrollIndicator {}
        }
    }
}
