pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls

Rectangle {
    id: strip
    required property bool fluid
    property int spacingChoice: 1
    property int inkChoice: 0
    property bool twelveHour: false
    property bool briefDate: false
    readonly property int trackingOffset: [-8, 0, 3][spacingChoice]
    readonly property var inks: fluid ? ["#30294d", "#603329", "#174652"]
                                     : ["#ffd064", "#ff9d78", "#81dece"]
    readonly property color chosenInk: inks[inkChoice]
    readonly property bool changed: spacingChoice !== 1 || inkChoice !== 0 || twelveHour || briefDate
    readonly property string sans: fluid ? "Noto Sans" : "Roboto Condensed"
    readonly property color stock: fluid ? "#e9e5f2" : "#e4dfcc"
    readonly property color ink: fluid ? "#30294d" : "#27282c"
    color: stock
    implicitHeight: groups.implicitHeight + 28

    component Choice: AbstractButton {
        id: button
        property bool selected: false
        property color swatch: "transparent"
        property bool showSwatch: false
        implicitWidth: label.implicitWidth + 24
        implicitHeight: 34
        contentItem: Item {
            Row {
                id: label
                spacing: 7
                anchors.centerIn: parent
                Rectangle {
                    visible: button.showSwatch
                    width: 12; height: 12; radius: strip.fluid ? 6 : 0
                    anchors.verticalCenter: parent.verticalCenter
                    color: button.swatch; border.width: 1; border.color: "#83808a"
                }
                Text {
                    text: button.text; font.family: strip.sans; font.pixelSize: 16
                    font.weight: button.selected ? Font.DemiBold : Font.Normal
                    color: button.selected ? strip.stock : strip.ink
                }
            }
        }
        background: Rectangle {
            radius: strip.fluid ? height / 2 : 0
            color: button.selected ? strip.ink : button.hovered ? "#26808080" : "transparent"
            border.width: button.visualFocus ? 2 : 0
            border.color: button.selected ? strip.stock : strip.ink
        }
    }

    component ChoiceGroup: Column {
        id: group
        required property string title
        required property var choices
        required property int current
        property var swatches: []
        signal picked(int value)
        spacing: 5
        Text {
            x: 4; text: group.title
            font.family: strip.fluid ? strip.sans : "DejaVu Sans Mono"
            font.pixelSize: 13; color: "#494653"
        }
        Row {
            spacing: 2
            Repeater {
                model: group.choices
                Choice {
                    required property int index
                    required property string modelData
                    objectName: "face-" + group.title + "-" + index
                    text: modelData
                    selected: group.current === index
                    Accessible.name: group.title + ", " + modelData
                    Accessible.checkable: true
                    Accessible.checked: selected
                    showSwatch: group.swatches.length > 0
                    swatch: showSwatch ? group.swatches[index] : "transparent"
                    onClicked: group.picked(index)
                }
            }
        }
    }

    Flow {
        id: groups
        x: 28; y: 14; width: parent.width - 56
        spacing: 24
        ChoiceGroup {
            title: "Day spacing"; choices: ["Close", "Original", "Wide"]; current: strip.spacingChoice
            onPicked: value => strip.spacingChoice = value
        }
        ChoiceGroup {
            title: "Date"; choices: ["Full", "Short"]; current: strip.briefDate ? 1 : 0
            onPicked: value => strip.briefDate = value === 1
        }
        ChoiceGroup {
            title: "Time"; choices: ["12 h", "24 h"]; current: strip.twelveHour ? 0 : 1
            onPicked: value => strip.twelveHour = value === 0
        }
        ChoiceGroup {
            title: "Clock ink"; choices: ["Original", "Copper", "Tide"]; current: strip.inkChoice
            swatches: strip.inks
            onPicked: value => strip.inkChoice = value
        }
        Item {
            width: reset.width; height: 55
            Choice {
                id: reset
                objectName: "resetFace"
                anchors.bottom: parent.bottom
                text: "Reset face"
                enabled: strip.changed
                opacity: enabled ? 1 : .45
                onClicked: {
                    strip.spacingChoice = 1;
                    strip.inkChoice = 0;
                    strip.twelveHour = false;
                    strip.briefDate = false;
                }
            }
        }
    }
}
