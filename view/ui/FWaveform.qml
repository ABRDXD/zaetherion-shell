import QtQuick
import QtQuick.Controls

Slider {
    id: root
    property bool reactive: false
    property int bars: 56
    // Spectrum bins 0..1 from the host; ignored unless reactive.
    property var spectrum: []
    readonly property var levels: reactive && visible ? spectrum : []
    padding: 0
    implicitHeight: 120
    hoverEnabled: true
    stepSize: 1
    Accessible.name: "Seek in track"
    background: Item {
        Repeater {
            model: root.bars
            Rectangle {
                id: band
                required property int index
                readonly property real amplitude: root.levels.length ? Math.min(1, Math.max(0, root.levels[Math.floor(index * root.levels.length / root.bars)])) : 0
                x: index * root.width / root.bars
                y: 4
                width: Math.max(2, root.width / root.bars - 3)
                height: Math.max(14, root.height - 8)
                transform: Scale { origin.y: band.height / 2; yScale: Math.max(14 / band.height, band.amplitude) }
                radius: 0
                color: (index + 0.5) / root.bars <= root.visualPosition ? Design.mediaAccent : Design.line
            }
        }
    }
    handle: Rectangle {
        visible: root.enabled
        x: root.visualPosition * (root.availableWidth - width)
        y: 0
        width: root.pressed || root.hovered || root.activeFocus ? 3 : 2
        height: root.height
        radius: 1
        color: Design.accent
    }
}
