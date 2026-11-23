import qs.view.cues
import qs.view.shell
import qs.view.ui
import QtQuick

// The archive on a bad tape (docs/OVERDRIVE.md §17), a stratum: `target` (the field archive) is drawn through
// shaders/tape.frag, hidden itself, rolling and tearing like a worn VHS, with a harder tracking glitch every few
// seconds. The tape wears where it has been played: each note's wear (FArchive.spans, from the seconds it has been in
// view) is painted into a one-pixel strip the shader reads, so worn passages shed oxide, bleed and fade, and the most
// worn carry a crease that never straightens. Over it, the deck's own display: PLAY, the speed and the counter, which
// counts every second the archive has ever played and is never rewound. Place it over the target, in its coordinates.
ShaderEffect {
    id: root
    property Item target: null
    property real phaseValue: 0
    property real glitchValue: 0
    readonly property var spans: target?.spans ?? []
    ShaderEffectSource {
        id: capture
        sourceItem: root.target
        hideSource: true
        live: true
        visible: false
    }
    // The wear strip: each note's span, red for its wear, and a thin band in blue where a worn note is creased.
    Item {
        id: strip
        width: 1
        height: root.height
        Repeater {
            model: root.spans
            Item {
                required property var modelData
                y: modelData.y
                width: 1
                height: modelData.h
                Rectangle {
                    anchors.fill: parent
                    color: Qt.rgba(modelData.wear, 0, 0, 1)
                }
                Rectangle {
                    visible: modelData.wear > 0.5
                    y: modelData.top + modelData.height * modelData.crease - modelData.y
                    width: 1
                    height: 5
                    color: Qt.rgba(modelData.wear, 0, 1, 1)
                }
            }
        }
    }
    ShaderEffectSource {
        id: wearMap
        sourceItem: strip
        hideSource: true
        live: true
        visible: false
        smooth: false
        textureSize: Qt.size(1, Math.max(1, Math.round(root.height)))
    }
    property var source: capture
    property var wearSource: wearMap
    blending: true
    fragmentShader: Qt.resolvedUrl("shaders/tape.frag.qsb")
    readonly property vector2d size: Qt.vector2d(width, height)
    readonly property real phase: phaseValue
    readonly property real alive: Motion.drive
    readonly property real glitch: glitchValue

    // The deck's display, in the top margin, clear of the archive's controls.
    function counter(s) {
        return Math.floor(s / 3600) + ":" + String(Math.floor(s / 60) % 60).padStart(2, "0") + ":" + String(s % 60).padStart(2, "0");
    }
    component Osd: FText {
        technical: true
        font.pixelSize: Design.control
        font.weight: Font.Bold
        color: "#f2f2ea"
        style: Text.Outline
        styleColor: Qt.rgba(0, 0, 0, 0.55)
        opacity: root.alive * (0.82 + 0.1 * Math.sin(root.phaseValue * 6.2831853 * 31))
    }
    Row {
        x: 28
        y: 6
        spacing: 18
        Osd { text: "▶ PLAY" }
        Osd { text: "SP" }
        Osd { text: root.glitchValue > 0.2 ? "TRACKING" : ""; color: "#ffd84d" }
    }
    Osd {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 6
        text: root.counter(ViewState.tapeSeconds)
    }
}
