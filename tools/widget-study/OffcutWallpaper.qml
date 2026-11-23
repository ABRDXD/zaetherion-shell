import QtQuick

// Fixed type specimen used as the wallpaper in this desktop fixture.
Rectangle {
    id: stock
    required property string family
    required property bool fluid
    property bool darkStock: false
    readonly property color ink: darkStock ? "#292d36" : fluid ? "#30294d" : "#41232b"
    color: darkStock ? "#535762" : fluid ? "#b7b0d0" : "#e3ac92"
    clip: true

    Item {
        x: 0
        y: parent.height * .61
        width: parent.width
        height: parent.height - y
        clip: true
        Text {
            // One enlargement of the SD pair from WEDNESDAY, cut through the
            // middle of both glyphs. The gap in S is also visible at clock scale.
            x: -parent.width * .13
            y: -font.pixelSize * .49
            text: "SD"
            font.family: stock.family
            font.pixelSize: Math.round(parent.width * .85)
            font.letterSpacing: -font.pixelSize * .05
            color: stock.ink
        }
    }
}
