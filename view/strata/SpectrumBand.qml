import qs.view.cues
import qs.view.ui
import QtQuick

// The Media visualiser (a stratum): the spectrum as bars leaning at 78°, rising from a hairline, with a
// faint reflection under it. One GPU quad (shaders/spectrum.frag); the bins are uniforms, so a new
// spectrum frame (30 a second, only while the room's lease is held) costs the CPU fourteen vectors and the
// GPU one small quad. Silence draws a still comb on the hairline. The software renderer draws no shaders.
ShaderEffect {
    id: root
    // 0..1 per bin, as the host's `spectrum` lease delivers it (56 bins); fewer are padded with zeros.
    property var spectrum: []
    property color bar: Design.accent
    property color line: Design.line

    function quad(i) {
        const s = spectrum ?? [];
        return Qt.vector4d(s[i * 4] ?? 0, s[i * 4 + 1] ?? 0, s[i * 4 + 2] ?? 0, s[i * 4 + 3] ?? 0);
    }

    blending: true
    fragmentShader: Qt.resolvedUrl("shaders/spectrum.frag.qsb")

    // The uniforms (shaders/spectrum.frag's block).
    readonly property real bandWidth: width
    readonly property real bandHeight: height
    readonly property real fill: 0.58
    readonly property real ground: 0.74
    readonly property real shear: Math.tan(12 * Math.PI / 180)
    readonly property real bins: 56
    readonly property color barColor: bar
    readonly property color lineColor: Qt.alpha(line, 0.7)
    readonly property vector4d s0: quad(0)
    readonly property vector4d s1: quad(1)
    readonly property vector4d s2: quad(2)
    readonly property vector4d s3: quad(3)
    readonly property vector4d s4: quad(4)
    readonly property vector4d s5: quad(5)
    readonly property vector4d s6: quad(6)
    readonly property vector4d s7: quad(7)
    readonly property vector4d s8: quad(8)
    readonly property vector4d s9: quad(9)
    readonly property vector4d s10: quad(10)
    readonly property vector4d s11: quad(11)
    readonly property vector4d s12: quad(12)
    readonly property vector4d s13: quad(13)
}
