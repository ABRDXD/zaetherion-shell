import qs.view.ui
import QtQuick
import "Geology.js" as G

// Thermal stratigraphy (atlas #16, docs/OVERDRIVE.md §28): a column of sediment in Performance's corner, one layer per
// weather report (core/weather.py), the oldest at the bottom. A long cool spell lays a thick pale band; a hot one is
// pressed thin and dark and warm. The machine's temperature as a geological record, not a live effect. Static.
Item {
    id: root
    property var strata: []
    implicitWidth: 14
    readonly property var layers: G.layers(strata, height)
    Repeater {
        model: root.layers
        Rectangle {
            required property var modelData
            y: modelData.y
            width: root.width
            height: Math.max(1, modelData.h - 1)
            color: Qt.tint(Design.faint, Qt.alpha(Design.danger, modelData.tone * 0.9))
            opacity: 0.18 + 0.6 * modelData.tone
            HoverHandler { id: layerHover }
            FText {
                visible: layerHover.hovered && Number.isFinite(parent.modelData.temp)
                x: -implicitWidth - 6
                y: (parent.height - implicitHeight) / 2
                text: Math.round(parent.modelData.temp) + "°C"
                technical: true
                font.pixelSize: 9   // scale: a layer's figure
                color: Design.muted
            }
        }
    }
    Rectangle { visible: root.layers.length > 0; y: root.height; width: root.width; height: 1; color: Design.line }
    FText {
        visible: root.layers.length > 0
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.height + 3
        text: "STRATA"
        technical: true
        font.pixelSize: 9   // scale: a layer's figure
        color: Design.faint
    }
}
