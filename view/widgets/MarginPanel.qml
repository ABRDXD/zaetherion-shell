pragma ComponentBehavior: Bound
import QtQuick

Rectangle {
    id: panel
    implicitWidth: 286
    required property bool fluid
    required property color stock
    required property color paper
    required property color signal
    required property string sans
    required property string labelFamily
    required property string tool
    required property string activeTool
    required property int column
    required property int span
    required property int angle
    required property int minimum
    required property int maximum
    readonly property int reading: tool === "Move" ? column + 1 : tool === "Resize" ? span : angle
    // The study's type sizes (tools/widget-editor-study), named for the type-scale rule.
    readonly property int wordSize: 17
    readonly property int fineSize: 13
    readonly property int titleSize: 32
    readonly property int toolSize: 22
    signal toolRequested(string tool)
    signal valueRequested(int value)

    component Words: Text {
        font.family: panel.sans
        font.pixelSize: panel.wordSize
    }
    component Fine: Words {
        font.family: panel.labelFamily
        font.pixelSize: panel.fineSize
    }

    color: panel.fluid ? "#e9e5f2" : "#e4dfcc"
    Item {
        x: 24; y: 40; width: parent.width - 48; height: parent.height - y
        Words { y: 7; text: "Modern Clock"; color: panel.stock; font.pixelSize: panel.titleSize; font.weight: Font.DemiBold }
        Rectangle { y: 77; width: parent.width; height: 1; color: "#858489" }
        Column {
            y: 97; width: parent.width; spacing: 6
            Repeater {
                model: ["Move", "Resize", "Rotate"]
                Rectangle {
                    id: control
                    objectName: "mode" + modelData
                    required property string modelData
                    readonly property bool chosen: panel.activeTool === modelData
                    width: parent.width; height: 52
                    radius: panel.fluid ? 16 : 0
                    color: chosen ? panel.stock : "transparent"
                    Words {
                        x: 13; anchors.verticalCenter: parent.verticalCenter; text: control.modelData
                        color: control.chosen ? panel.paper : panel.stock; font.pixelSize: panel.toolSize
                        font.weight: control.chosen ? Font.DemiBold : Font.Normal
                    }
                    Fine {
                        anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter
                        text: control.modelData === "Move" ? "col " + (panel.column + 1) : control.modelData === "Resize" ? panel.span + " col" : panel.angle + "°"
                        color: control.chosen ? panel.signal : "#494750"
                    }
                    TapHandler { onTapped: panel.toolRequested(control.modelData) }
                }
            }
        }
        SettingGauge {
            x: 2; y: 281; width: parent.width - 4; height: 62
            tool: panel.tool; fluid: panel.fluid
            minimum: panel.minimum; maximum: panel.maximum; reading: panel.reading
            onValueRequested: value => panel.valueRequested(value)
        }
        Fine {
            y: 365; width: parent.width; wrapMode: Text.WordWrap; color: "#48454e"
            text: panel.tool === "Move" ? "Set the starting column on the ruler. Drag the clock to place it vertically."
                : panel.tool === "Resize" ? "Set the width in columns on the ruler, or drag across the clock."
                : "Set the angle on the ruler, or turn the clock about its centre."
        }
    }
}
