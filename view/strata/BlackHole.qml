import qs.view.ui
import QtQuick

// The 3D black hole of the orbit's centre (shaders/blackhole.frag). Runs in shell-heavy.qml, on the NVIDIA card.
ShaderEffect {
    property real centreX: width / 2
    property real centreY: height / 2
    property real radius: 120
    property real elevation: 45
    property real time: 0
    fragmentShader: Qt.resolvedUrl("shaders/blackhole.frag.qsb")
    readonly property vector2d size: Qt.vector2d(width, height)
    readonly property vector2d centre: Qt.vector2d(centreX, centreY)
    readonly property real tilt: elevation * Math.PI / 180
    // The theme, as the panel sends it: this runs in a process of its own, with no host to ask.
    property color accent: Design.accent
    property color hot: Design.ink
    property color background: Design.background
    readonly property color deep: Qt.darker(background, 2.4)
    // What lies behind the hole: the Medium, bent by the same rays.
    property variant sky
}
