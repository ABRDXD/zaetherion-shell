import qs.view.cues
import QtQuick
import QtQuick.Controls
import Quickshell

AbstractButton {
    id: root
    property string symbol: ""
    property string label: ""
    property string hint: ""
    property bool selected: false
    property bool primary: false
    property bool danger: false
    property int iconSize: 22
    property color baseColor: Design.buttonSurface
    property color outlineColor: Design.line
    implicitHeight: 38
    implicitWidth: symbol === "" ? textLabel.implicitWidth + 22 : label === "" ? 38 : textLabel.implicitWidth
                                                                                 + 49
    hoverEnabled: true
    leftPadding: 10
    rightPadding: 10
    topPadding: 5
    bottomPadding: 5
    opacity: enabled ? 1 : 0.45
    Accessible.name: label || hint
    // The host's own click sound, through the core's gate (Feedback).
    onClicked: Feedback.play("ui.click")
    // Hover, press and selection wipe the button to ink (the sheet's inversion); selection adds the rules.
    // Primary and danger buttons keep their own fills.
    readonly property bool plain: !primary && !danger
    readonly property real wipeProgress: wipe.progress
    readonly property color contentColor: danger ? Design.danger : primary ? Design.background : wipe.ink
    background: Item {
        property alias frame: frame
        FFrame {
            id: frame
            anchors.fill: parent
            fillColor: root.danger ? Qt.alpha(Design.danger, root.hovered ? 0.25 : 0.12) : root.primary ? Design.selected : root.baseColor
            lineColor: root.activeFocus ? Design.ink : root.danger ? Design.danger : root.selected ? Design.ink : root.outlineColor
            Tween on fillColor {
                scope: root
                ColorAnimation {
                    duration: Motion.feedback
                    easing.type: Motion.roles.feedback.easing
                }
            }
        }
        Wipe {
            id: wipe
            anchors.fill: parent
            scope: root
            on: root.plain && (root.hovered || root.down || root.selected)
            ruled: root.plain && root.selected
        }
    }
    // Explicit glyph box avoids font baseline metrics shifting icon-only controls.
    contentItem: Item {
        Row {
            anchors.centerIn: parent
            spacing: 7
            Item {
                visible: root.symbol !== ""
                width: root.iconSize
                height: root.iconSize
                MaterialSymbol {
                    visible: root.symbol !== "pause"
                    anchors.fill: parent
                    text: root.symbol
                    iconSize: root.iconSize
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    color: root.contentColor
                }
                Row {
                    visible: root.symbol === "pause"
                    anchors.centerIn: parent
                    spacing: root.iconSize * 0.16
                    Repeater {
                        model: 2
                        Rectangle {
                            width: root.iconSize * 0.22
                            height: root.iconSize * 0.7
                            color: root.contentColor
                        }
                    }
                }
            }
            FText {
                id: textLabel
                visible: root.label !== ""
                text: root.label
                width: Math.min(implicitWidth, Math.max(0, root.availableWidth - (root.symbol !== "" ? 27 :
                                                                                                       0)))

                height: root.iconSize
                verticalAlignment: Text.AlignVCenter
                font.pixelSize: Design.control
                color: root.contentColor
            }
        }
    }
    transform: Translate {
        y: root.down ? 1 : 0
    }
    ToolTip.visible: hovered && hint !== ""
    ToolTip.text: hint
    ToolTip.delay: 600
}
