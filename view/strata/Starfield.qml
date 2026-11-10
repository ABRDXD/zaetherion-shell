import qs.view.cues
import qs.view.ui
import QtQuick

// Deep space behind the orbit (docs/OVERDRIVE.md §5), a stratum: procedural stars in three parallax layers
// (shaders/starfield.frag) that follow the orbit camera and twinkle. One quad, no textures; the CPU only
// passes the camera and the twinkle's phase.
ShaderEffect {
    id: root
    property real camX: 0
    property real camY: 0
    property real camS: 1
    property real twinklePhase: 0
    blending: true
    fragmentShader: Qt.resolvedUrl("shaders/starfield.frag.qsb")
    // The uniforms (shaders/starfield.frag's block).
    readonly property vector2d size: Qt.vector2d(width, height)
    readonly property vector2d cam: Qt.vector2d(camX, camY)
    readonly property real zoom: camS
    readonly property real twinkle: twinklePhase
    readonly property real alive: Motion.drive
    readonly property real density: 0.42
    readonly property color starColor: Qt.alpha(Design.ink, 0.9)
    readonly property color warmColor: Design.warm
}
