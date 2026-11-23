import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.view.cues
import qs.view.ui

// FART's numbered index: the selected section receives the white cut.
ColumnLayout {
    id: root

    property var sections: []
    property string section: ""

    signal picked(string section)
    signal closed

    spacing: Design.baseline * 2

    FText {
        Layout.fillWidth: true
        text: "SETTINGS"
        headline: true
        font.pixelSize: Design.headline
        font.weight: Font.DemiBold
    }

    FRule {
        Layout.fillWidth: true
    }

    Repeater {
        model: root.sections

        AbstractButton {
            id: tab

            required property var modelData
            required property int index
            readonly property bool selected: root.section === modelData[0]

            objectName: "section-" + modelData[0]
            Layout.fillWidth: true
            implicitHeight: Design.minHit + Design.baseline * 5
            hoverEnabled: true
            Accessible.name: modelData[1]
            Accessible.description: (selected ? "Selected. " : "") + "Settings section " + (index + 1) + " of " + root.sections.length
            Accessible.role: Accessible.PageTab
            onClicked: {
                Feedback.play("ui.click");
                root.picked(modelData[0]);
            }

            background: Item {
                SettingsCut {
                    anchors.fill: parent
                    color: tab.selected ? Design.selected : tab.hovered || tab.down ? Design.hover : "transparent"

                    Tween on color {
                        scope: tab

                        ColorAnimation {
                            duration: Motion.feedback
                            easing.type: Motion.roles.feedback.easing
                        }
                    }
                }

                Reticle {
                    anchors.fill: parent
                    visible: tab.activeFocus
                }
            }

            contentItem: RowLayout {
                spacing: Design.baseline * 2

                Item {
                    Layout.preferredWidth: Design.baseline * 3
                }

                FText {
                    text: String(tab.index + 1).padStart(2, "0")
                    headline: true
                    font.pixelSize: Design.figure
                    color: tab.selected ? Design.background : Design.muted
                }

                FText {
                    Layout.fillWidth: true
                    text: tab.modelData[1]
                    technical: true
                    font.letterSpacing: 0
                    color: tab.selected ? Design.background : Design.ink
                }

                Item {
                    Layout.preferredWidth: Design.baseline * 2
                }
            }
        }
    }

    Item {
        Layout.fillHeight: true
    }

    FRule {
        Layout.fillWidth: true
    }

    FButton {
        Layout.fillWidth: true
        objectName: "settingsClose"
        label: "Close settings"
        symbol: "close"
        onClicked: root.closed()
    }
}
