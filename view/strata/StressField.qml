import qs.view.cues
import qs.view.ui
import QtQuick

// The wallpaper under load (OVERDRIVE_IDEAS #52), a stratum on the desktop tier: fringes of equal stress spreading from the
// panel's corners (shaders/stress.frag). Nothing animates here: it redraws when the room or the engine changes.
ShaderEffect {
    id: root
    property rect panelRect: Qt.rect(0, 0, 0, 0)
    property real turnValue: 0
    blending: true
    fragmentShader: Qt.resolvedUrl("shaders/stress.frag.qsb")
    readonly property vector2d size: Qt.vector2d(width, height)
    readonly property vector4d panel: Qt.vector4d(panelRect.x, panelRect.y, panelRect.width, panelRect.height)
    readonly property real turn: turnValue
    readonly property real alive: Motion.drive
    readonly property real strength: 0.34
    readonly property color lineColor: Qt.alpha(Design.ink, 0.8)
    readonly property color glowColor: Design.accent
}
