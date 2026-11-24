import QtQuick

QtObject {
    required property bool fluid
    readonly property color ink: fluid ? "#fbf2ff" : "#fff2dc"
    readonly property color accent: fluid ? "#e1c8fc" : "#ffbf6a"
    readonly property color alert: "#ffb9a4"
    readonly property int small: 13
    readonly property int body: 18
    readonly property int track: 21
    readonly property int dateSize: fluid ? 24 : 22
    readonly property int clockSize: fluid ? 115 : 127
}
