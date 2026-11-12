import QtQuick
Text {
    property int iconSize: 22
    // Material Symbols' variable axes: FILL 0–1 and weight 100–700. The defaults draw the outlined glyph as before.
    property real fill: 0
    property int weight: 400
    font.family: "Material Symbols Rounded"
    font.pixelSize: iconSize
    font.italic: false
    font.variableAxes: ({ "FILL": fill, "wght": weight })
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
}
