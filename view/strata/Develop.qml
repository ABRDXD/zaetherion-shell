import qs.view.ui
import QtQuick

// A capture developing from a negative (view/overdrive/ContactSheet.qml, shaders/develop.frag). Used as a layer effect.
ShaderEffect {
    property real progress: 0
    property real seed: 0
    fragmentShader: Qt.resolvedUrl("shaders/develop.frag.qsb")
    readonly property vector2d size: Qt.vector2d(width, height)
    readonly property color tint: Design.warm
}
