import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.view.cues
import qs.view.ui

// A reading is the entrance to its alternatives. No state is written on open.
AbstractButton {
    id: root

    property string label: ""
    property string valueLabel: ""
    property string note: ""
    property bool prominent: false
    property bool compact: false
    property bool expanded: false
    // Not known (Z219): a hatched bar and this word take the value's place; the reading keeps its height.
    property string missing: ""
    readonly property var numberAndUnit: /^([0-9][0-9 .,]*)\s+(s|MB|day|days)$/.exec(valueLabel)

    hoverEnabled: true
    implicitWidth: Math.max(Design.baseline * 28, readout.implicitWidth + (unit.visible ? unit.implicitWidth + Design.baseline * 2 : 0) + Design.baseline * 16)
    implicitHeight: (compact ? Design.readout : prominent ? Design.headline : Design.figure) + Design.baseline * 4
    leftPadding: Design.baseline * 5
    rightPadding: Design.baseline * 5
    topPadding: Design.baseline
    bottomPadding: Design.baseline
    opacity: enabled ? 1 : 0.45
    Accessible.name: label + ": " + (missing ? missing.toLowerCase() : valueLabel)
    Accessible.description: note + (expanded ? ". Alternatives open" : ". Show alternatives")
    onClicked: Feedback.play("ui.click")
    ToolTip.visible: hovered
    ToolTip.text: label + ": " + valueLabel + (note ? " · " + note : "")
    ToolTip.delay: 600

    background: Item {
        SettingsCut {
            anchors.fill: parent
            color: root.prominent ? Design.selected : root.hovered || root.down ? Design.hover : "transparent"

            Tween on color {
                scope: root

                ColorAnimation {
                    duration: Motion.feedback
                    easing.type: Motion.roles.feedback.easing
                }
            }
        }

        Reticle {
            anchors.fill: parent
            visible: root.activeFocus
        }
    }

    contentItem: RowLayout {
        spacing: Design.baseline

        Item {
            visible: root.missing !== ""
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: Design.baseline * 12
            implicitHeight: Design.baseline * 2
            clip: true
            Hatch {
                anchors.fill: parent
                pitch: 5
                color: Design.muted
                strength: 0.7
            }
        }
        FText {
            visible: root.missing !== ""
            Layout.alignment: Qt.AlignVCenter
            text: root.missing
            technical: true
            font.letterSpacing: 1
            color: Design.muted
        }

        FText {
            id: readout
            visible: root.missing === ""

            Layout.fillWidth: true
            Layout.alignment: Qt.AlignBaseline
            text: root.numberAndUnit ? root.numberAndUnit[1] : root.valueLabel
            headline: true
            font.pixelSize: root.compact ? Design.readout : root.prominent ? Design.headline : Design.figure
            font.weight: Font.DemiBold
            horizontalAlignment: Text.AlignHCenter
            color: root.prominent ? Design.background : Design.ink
        }

        FText {
            id: unit

            Layout.alignment: Qt.AlignBaseline
            visible: root.numberAndUnit !== null && root.missing === ""
            text: root.numberAndUnit ? root.numberAndUnit[2] : ""
            font.pixelSize: root.compact ? Design.caption : Design.readout
            font.capitalization: Font.MixedCase
            color: root.prominent ? Design.background : Design.ink
        }

        FText {
            Layout.alignment: Qt.AlignVCenter
            visible: root.missing === ""
            text: root.expanded ? "−" : "+"
            technical: true
            color: root.prominent ? Design.background : Design.muted
        }
    }
}
