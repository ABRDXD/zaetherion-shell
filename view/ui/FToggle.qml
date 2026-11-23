import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

AbstractButton {
    id: root
    property string label: ""
    property string symbol: ""
    property bool selected: false
    implicitHeight: 64
    implicitWidth: 130
    hoverEnabled: true
    Accessible.name: label + (selected ? ", on" : ", off")
    Accessible.role: Accessible.CheckBox
    Accessible.checked: selected
    onClicked: Feedback.play("ui.switch")
    // On is the sheet's inversion with its rules; hover only lifts the paper.
    background: Item {
        FFrame {
            anchors.fill: parent
            radius: Design.radiusCard
            fillColor: root.hovered && !root.selected ? Design.hover : Design.surface
            lineColor: root.activeFocus ? Design.accent : root.selected ? Design.ink : Design.line
        }
        Wipe {
            id: wipe
            anchors.fill: parent
            scope: root
            on: root.selected
            ruled: true
        }
    }
    contentItem: ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 4
        RowLayout {
            MaterialSymbol { text: root.symbol; iconSize: 20; color: wipe.ink }
            Item { Layout.fillWidth: true }
            FText {
                text: root.selected ? "ON" : "OFF"
                technical: true
                font.pixelSize: Design.caption
                color: wipe.inverted ? wipe.ink : Design.muted
            }
        }
        FText { text: root.label; color: wipe.ink; font.pixelSize: Design.control }
    }
}
