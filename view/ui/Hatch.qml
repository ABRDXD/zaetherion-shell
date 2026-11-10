import QtQuick

// A hatched band (MONTAGE.md §4.4): parallel strokes at 78°, one tiled inline-SVG cell, so
// any size costs one texture. The cell is `pitch` wide and pitch / tan(12°) tall, so the strokes meet
// across tile seams. Static.
Image {
    id: root
    property int pitch: 6
    property real stroke: 1.5
    property color color: Design.ink
    property real strength: 0.5
    readonly property int cellHeight: Math.round(pitch / Math.tan(12 * Math.PI / 180))
    readonly property string hex: "%23" + String(color).slice(-6)
    readonly property string segment: "' stroke='" + hex + "' stroke-opacity='" + strength + "' stroke-width='" + stroke + "'/>"
    source: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' width='" + pitch + "' height='" + cellHeight + "'>"
        + "<path d='M0 " + cellHeight + "L" + pitch + " 0" + segment
        + "<path d='M" + (-pitch) + " " + cellHeight + "L0 0" + segment
        + "<path d='M" + pitch + " " + cellHeight + "L" + (2 * pitch) + " 0" + segment + "</svg>"
    sourceSize: Qt.size(pitch, cellHeight)
    fillMode: Image.Tile
    smooth: false
    cache: false
}
