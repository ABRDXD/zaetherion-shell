import QtQuick
import QtQuick.Controls

TextField {
    id: root
    implicitHeight: 40
    implicitWidth: 160
    color: Design.ink
    placeholderTextColor: Design.muted
    font.family: Design.mono
    font.italic: false
    font.styleName: "Regular"
    font.features: ({ "tnum": 1 })
    font.pixelSize: Design.control
    selectionColor: Design.accent
    selectedTextColor: Design.background
    leftPadding: 12
    rightPadding: 12
    background: FFrame {
        fillColor: Design.surface
        lineColor: root.activeFocus ? Design.accent : Design.line
    }
}
