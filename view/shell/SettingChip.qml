import QtQuick
import QtQuick.Controls
import qs.view.cues
import qs.view.fluid
import qs.view.ui

// One alternative under a Settings reading (Cutline, Z218; chips Z219). The current value is a white cut (an ink
// plane leaning at 78°, as the selected section in the index); the others are plain mono words that lift on hover.
// A radio in a radio group: SettingChoices moves focus between them with the arrow keys.
AbstractButton {
    id: root
    property string label: ""
    property bool selected: false
    hoverEnabled: true
    focusPolicy: Qt.StrongFocus
    checkable: false
    implicitHeight: Design.minHit + Design.baseline
    implicitWidth: Math.max(implicitHeight, word.implicitWidth + 2 * (Design.baseline * 2 + cut.run))
    Accessible.role: Accessible.RadioButton
    Accessible.name: label
    Accessible.checked: selected
    onClicked: Feedback.play("ui.click")
    background: Item {
        Rectangle {
            anchors.fill: parent
            radius: Design.fluid ? height / 2 : 0
            color: Design.fluid && root.selected ? FluidTokens.accent : Design.hover
            opacity: (Design.fluid && root.selected) || (root.hovered && !root.selected) ? 1 : 0
            Tween on opacity { scope: root; NumberAnimation { duration: Motion.feedback; easing.type: Motion.roles.feedback.easing } }
        }
        Plane {
            id: cut
            anchors.fill: parent
            role: "ink"
            slant: 3
            visible: !Design.fluid && root.selected
        }
        Rectangle {
            anchors.fill: parent
            color: "transparent"
            border.width: 1
            border.color: root.selected ? Design.background : Design.ink
            radius: Design.fluid ? height / 2 : 0
            visible: root.visualFocus
        }
    }
    contentItem: FText {
        id: word
        text: root.label
        technical: true
        font.family: Design.fluid ? FluidTokens.sans : Design.mono
        font.pixelSize: Design.fluid ? FluidTokens.body : Design.body
        font.weight: root.selected ? Font.Bold : Font.Normal
        font.capitalization: Font.MixedCase
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        color: root.selected ? (Design.fluid ? FluidTokens.base : cut.textColor) : root.hovered || root.visualFocus ? Design.ink : Design.muted
    }
    transform: Translate { y: root.down ? 1 : 0 }
}
