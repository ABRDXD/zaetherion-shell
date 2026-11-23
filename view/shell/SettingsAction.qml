import QtQuick
import QtQuick.Controls
import qs.view.cues
import qs.view.fluid
import qs.view.ui

// A quiet action in a Settings section (Cutline, Z218; Z219): mono words over a hairline, with an arrow. Hover
// lifts the words to ink and the line with them; focus draws a frame; disabled fades to faint. `confirm` makes it ask
// twice (ConfirmArm): armed, it reads `armedLabel` in the danger colour, and a Cancel beside it disarms.
// In a Side column row (SettingsSideRow) the main verb `leads` with "›" in bold ink, and `underline: false` drops
// the hairline until hover or focus.
AbstractButton {
    id: root
    property string label: ""
    property string armedLabel: label + "?"
    property string glyph: "↗"
    property bool confirm: false
    property bool danger: false
    property bool lit: false // a state that is on (Trusted): the accent
    property bool leads: false
    property bool underline: true
    readonly property alias armed: arm.armed
    signal activated()
    hoverEnabled: true
    focusPolicy: Qt.StrongFocus
    // Faded when off, like the chips: faint alone can match muted in some palettes.
    opacity: enabled ? 1 : 0.45
    implicitHeight: Design.minHit + Design.baseline * 2
    implicitWidth: words.implicitWidth + (cancel.visible ? cancel.implicitWidth + Design.baseline * 3 : 0)
    Accessible.role: Accessible.Button
    Accessible.name: armed ? armedLabel : label
    onClicked: {
        Feedback.play("ui.click");
        if (confirm) arm.press();
        else activated();
    }
    onEnabledChanged: if (!enabled) arm.cancel()
    ConfirmArm { id: arm; onConfirmed: root.activated() }

    readonly property color tone: !enabled ? Design.faint
        : armed || danger ? Design.danger
        : lit ? Design.accent
        : hovered || visualFocus || leads ? Design.ink : Design.muted
    background: Item {
        Rectangle {
            y: parent.height - 1
            width: words.implicitWidth
            height: 1
            color: root.tone
            opacity: (Design.fluid || !root.underline) && !root.hovered && !root.visualFocus ? 0 : root.enabled ? 1 : 0.5
            Tween on color { scope: root; ColorAnimation { duration: Motion.feedback; easing.type: Motion.roles.feedback.easing } }
        }
        Rectangle {
            x: -Design.baseline
            width: words.implicitWidth + Design.baseline * 2
            height: parent.height
            color: "transparent"
            border.width: 1
            border.color: Design.ink
            visible: root.visualFocus
        }
    }
    contentItem: Item {
        SettingsText {
            id: words
            anchors.verticalCenter: parent.verticalCenter
            text: (root.leads ? "›  " : "") + (root.armed ? root.armedLabel : root.label) + (root.glyph && !root.leads ? "  " + root.glyph : "")
            font.bold: root.leads
            technical: true
            font.pixelSize: Design.control
            font.capitalization: Font.MixedCase
            color: root.tone
            Tween on color { scope: root; ColorAnimation { duration: Motion.feedback; easing.type: Motion.roles.feedback.easing } }
        }
    }
    // Disarm without acting.
    AbstractButton {
        id: cancel
        objectName: root.objectName ? root.objectName + "Cancel" : ""
        x: words.implicitWidth + Design.baseline * 3
        height: root.height
        visible: root.armed
        hoverEnabled: true
        focusPolicy: Qt.StrongFocus
        implicitWidth: cancelWords.implicitWidth
        Accessible.role: Accessible.Button
        Accessible.name: "Cancel"
        onClicked: { Feedback.play("ui.click"); arm.cancel(); root.forceActiveFocus(); }
        contentItem: SettingsText {
            id: cancelWords
            verticalAlignment: Text.AlignVCenter
            text: "Cancel"
            technical: true
            font.pixelSize: Design.control
            font.capitalization: Font.MixedCase
            color: cancel.hovered || cancel.visualFocus ? Design.ink : Design.muted
        }
        background: Rectangle {
            y: parent.height - 1
            width: parent.width
            height: 1
            color: cancel.hovered || cancel.visualFocus ? Design.ink : Design.line
        }
    }
}
