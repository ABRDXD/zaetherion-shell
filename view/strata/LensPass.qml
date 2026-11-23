import qs.view.cues
import qs.view.ui
import QtQuick

// The lensing transition (M13, docs/OVERDRIVE.md §5): for the first part of a room switch the room you are leaving is
// drawn through a gravitational lens standing at the room you chose. It is loaded for as long as Overdrive runs, so
// it is ready when a switch starts, but it captures nothing between switches: `target` is only attached while
// `active`, and the texture is released with it. Place it over the target, in the same coordinates.
ShaderEffect {
    id: root
    property Item target: null
    property bool active: false
    // 0..1..0 over the pass.
    property real strength: 0
    property point lensAt: Qt.point(0, 0)
    visible: active
    ShaderEffectSource {
        id: capture
        sourceItem: root.active ? root.target : null
        hideSource: root.active
        live: root.active
        visible: false
    }
    property var source: capture
    blending: true
    fragmentShader: Qt.resolvedUrl("shaders/lens.frag.qsb")
    readonly property vector2d size: Qt.vector2d(Math.max(1, width), Math.max(1, height))
    readonly property vector2d centre: Qt.vector2d(lensAt.x, lensAt.y)
    readonly property real einstein: strength * Math.min(width, height) * 0.34
    readonly property real split: strength * 9
    readonly property color tint: Design.accent
}
