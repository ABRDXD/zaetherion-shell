import QtQuick
import QtQuick.Window
import QtQuick.Layouts

// A standalone Qt fixture. It only draws invented timer and Settings readings.
Window {
    id: window
    width: 990
    height: 492
    visible: true
    title: "ZÆTHERION · Type roles"
    readonly property bool fluid: Qt.application.arguments.includes("--fluid")
    readonly property string prose: fluid ? "Inter" : "Roboto Condensed"
    readonly property string mono: "JetBrainsMono Nerd Font"
    readonly property color ink: "#f4f0e6"
    readonly property color quiet: "#b1bbbd"
    readonly property color rule: "#495357"
    readonly property color warm: "#ffd19a"
    readonly property var reading: ({ caption: 12, action: 15, body: 16, heading: 26, figure: 34, headline: 42, display: 72 })
    readonly property var instrument: ({ caption: 12, action: 14, body: 14, heading: 20, figure: 40, headline: 52, display: 88 })
    color: "#22292c"

    component SampleText: Text {
        color: window.ink
        font.family: window.prose
        textFormat: Text.PlainText
        elide: Text.ElideRight
    }

    component Page: Item {
        id: page
        required property bool numbersFirst
        readonly property var scale: numbersFirst ? window.instrument : window.reading
        readonly property string units: window.fluid ? window.prose : window.mono
        readonly property int inset: 20
        SampleText {
            x: 0; y: 0; width: parent.width
            text: page.numbersFirst ? "B · Numbers first" : "A · Reading first"
            font.pixelSize: window.reading.heading
            font.weight: Font.DemiBold
        }
        Rectangle {
            x: 0; y: 49; width: parent.width; height: 212
            radius: window.fluid ? 16 : 0
            color: "#111b22"
            SampleText {
                x: page.inset; y: 14; width: parent.width - 2*x
                text: window.fluid ? "Timer" : "TIMER"
                font.family: page.units; font.pixelSize: page.scale.caption
                color: window.quiet
            }
            SampleText {
                x: page.inset; y: 36; width: parent.width - 2*x
                text: "Focus session"
                font.pixelSize: page.scale.heading; font.weight: Font.DemiBold
            }
            SampleText {
                x: page.inset; y: 68; width: parent.width - 2*x; height: 92
                verticalAlignment: Text.AlignVCenter
                text: "08:42"
                font.family: page.numbersFirst ? window.mono : window.prose
                font.pixelSize: page.scale.display
                font.weight: page.numbersFirst ? Font.Medium : Font.DemiBold
                color: window.warm
            }
            Rectangle { x: page.inset; y: 166; width: parent.width - 2*x; height: 1; color: window.rule }
            RowLayout {
                x: page.inset; y: 174; width: parent.width - 2*x; height: 29; spacing: 16
                SampleText {
                    Layout.fillWidth: true
                    text: "Index the observation plates"
                    font.pixelSize: page.scale.body
                }
                SampleText {
                    text: "Pause"
                    font.family: page.units; font.pixelSize: page.scale.action; font.weight: Font.DemiBold
                }
            }
        }
        Rectangle {
            x: 0; y: 273; width: parent.width; height: 163
            radius: window.fluid ? 16 : 0
            color: "#172129"
            SampleText {
                x: page.inset; y: 13; text: window.fluid ? "Settings" : "SETTINGS"
                font.family: page.units; font.pixelSize: page.scale.caption; color: window.quiet
            }
            SampleText {
                x: page.inset; y: 34; text: "Bluetooth"
                font.pixelSize: page.scale.heading; font.weight: Font.DemiBold
            }
            Rectangle { x: page.inset; y: 77; width: parent.width - 2*x; height: 1; color: window.rule }
            SampleText {
                x: page.inset; y: 91; width: divider.x - x - 12
                text: "Studio headphones"
                font.pixelSize: page.scale.body; font.weight: Font.DemiBold
            }
            SampleText {
                x: page.inset; y: 117; width: divider.x - x - 12
                text: "Connected · 80% battery"
                font.family: page.units; font.pixelSize: page.scale.caption; color: window.quiet
            }
            Rectangle { id: divider; x: parent.width * 0.67; y: 92; width: 1; height: 42; color: window.rule }
            SampleText {
                x: divider.x + 13; y: 91; width: parent.width - x - page.inset
                text: "›  Disconnect"
                font.family: page.units; font.pixelSize: page.scale.action; font.weight: Font.DemiBold
            }
        }
    }

    Item {
        id: sheet
        anchors.fill: parent
        Rectangle { anchors.fill: parent; color: window.color }
        Row {
            x: 18; y: 14; spacing: 18
            Page { width: 468; height: 436; numbersFirst: false }
            Page { width: 468; height: 436; numbersFirst: true }
        }
        SampleText {
            x: 18; y: 463
            text: window.fluid ? "Fluid" : "Angular"
            color: window.quiet
            font.family: window.mono; font.pixelSize: window.reading.caption
        }
    }

    Timer {
        interval: 200
        running: Qt.application.arguments.includes("--out")
        onTriggered: {
            const args = Qt.application.arguments;
            const path = args[args.indexOf("--out") + 1];
            sheet.grabToImage(result => Qt.exit(result.saveToFile(path) ? 0 : 1));
        }
    }
}
