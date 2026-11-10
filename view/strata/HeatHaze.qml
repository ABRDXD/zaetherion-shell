import qs.view.cues
import qs.view.ui
import QtQuick

// The heat haze (docs/OVERDRIVE.md §8), a stratum: `target` (the header) is drawn through shaders/heat.frag,
// hidden itself, shimmering as hard as `heat` says. Place it over the target, in the same coordinates.
ShaderEffect {
    id: root
    property Item target: null
    property real heatLevel: 0
    property real phaseValue: 0
    ShaderEffectSource {
        id: capture
        sourceItem: root.target
        hideSource: true
        live: true
        visible: false
    }
    property var source: capture
    blending: true
    fragmentShader: Qt.resolvedUrl("shaders/heat.frag.qsb")
    readonly property vector2d size: Qt.vector2d(width, height)
    readonly property real heat: heatLevel * Motion.drive
    readonly property real phase: phaseValue
    readonly property color tint: Design.warm
}
