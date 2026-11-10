import qs.view.cues
import qs.view.ui
import QtQuick

// The ignition's shockwave (docs/OVERDRIVE.md §2), a stratum: while its ring runs out from `origin` across
// `target`, the target is drawn through shaders/shockwave.frag (hidden itself) and bent by the ring. One run of
// `duration` ms, then `finished()`; the Stratum around it unloads it and the target draws itself again.
// Place it over the target, in the same coordinates.
ShaderEffect {
    id: root
    property Item target: null
    property point origin: Qt.point(0, 0)
    property int duration: Math.round(1100 * Motion.timeScale)
    property real t: 0
    signal finished()
    readonly property real reach: Math.hypot(Math.max(origin.x, width - origin.x), Math.max(origin.y, height - origin.y)) + 80

    ShaderEffectSource {
        id: capture
        sourceItem: root.target
        hideSource: true
        live: true
        visible: false
    }
    property var source: capture
    blending: true
    fragmentShader: Qt.resolvedUrl("shaders/shockwave.frag.qsb")

    // The uniforms (shaders/shockwave.frag's block).
    readonly property vector2d size: Qt.vector2d(width, height)
    readonly property vector2d centre: Qt.vector2d(origin.x, origin.y)
    readonly property real radius: t * reach
    readonly property real ringWidth: 34 + 70 * t
    readonly property real strength: 26 * (1 - t)
    readonly property real split: 7 * (1 - t)
    readonly property real glow: 0.55 * (1 - t)
    readonly property color tint: Design.accent

    NumberAnimation {
        id: run
        target: root
        property: "t"
        from: 0
        to: 1
        duration: root.duration
        easing.type: Easing.OutCubic
        running: true
        onFinished: root.finished()
    }
    Activity { name: "overdrive.shockwave"; running: run.running }
}
