import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ColumnLayout {
    id: root
    property string label: ""
    property string symbol: ""
    property real value: 0
    property bool muted: false
    signal moved(real value)
    signal iconClicked
    spacing: 8
    RowLayout {
        Layout.fillWidth: true
        FButton {
            symbol: root.symbol
            hint: root.label
            implicitHeight: 28
            implicitWidth: 30
            selected: root.muted
            onClicked: root.iconClicked()
        }
        FText {
            text: root.label
            Layout.fillWidth: true
            font.pixelSize: Design.body
            color: Design.muted
        }
        FText {
            text: Math.round(slider.value) + "%"
            technical: true
            color: root.muted ? Design.faint : Design.ink
        }
    }
    Slider {
        id: slider
        Layout.fillWidth: true
        implicitHeight: 24
        leftPadding: 0
        rightPadding: 0
        Accessible.name: root.label
        from: 0
        to: 100
        value: root.value
        onMoved: root.moved(value)
        background: Rectangle {
            x: slider.leftPadding
            y: slider.topPadding + slider.availableHeight / 2 - 3
            width: slider.availableWidth
            height: 6
            radius: 1
            color: Design.line
            Rectangle {
                width: parent.width * slider.visualPosition
                height: 6
                radius: 1
                color: root.muted ? Design.faint : Design.ink
            }
        }
        handle: Rectangle {
            x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
            y: slider.topPadding + (slider.availableHeight - height) / 2
            width: 18
            height: 18
            radius: 1
            color: Design.ink
        }
    }
}
