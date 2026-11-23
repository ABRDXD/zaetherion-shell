import qs.view.cues
import QtQuick
import "../ui/Sundial.js" as S

// Sundial rooms (docs/OVERDRIVE.md §43; B's own idea), the Stratum `sheet.sundial` under the room, on the GPU: the
// room's content casts a shadow on its sheet from where the sun really is (the screen read as a map, face up, north at
// the top), from the moon at night as strongly as it is lit, and none with both down. The sky comes from the core
// (`sky.now`, once a minute while this exists); the content's alpha from a KeepOut of the room's viewport.
Item {
    id: root
    property Item viewport: null
    property var core: null
    property var sky: null
    readonly property var light: S.light(sky)
    readonly property var cast: S.shadow(light)
    opacity: Motion.drive
    Timer {
        interval: 60000
        repeat: true
        running: !!root.core
        triggeredOnStart: true
        onTriggered: root.core.request("sky.now", {}, (ok, result) => { if (ok && result && root) root.sky = result; })
    }
    // The sheet's own KeepOut of the same viewport, when the Shell passes it: one capture of the room instead of two
    // (the room is drawn again into each on every change of its content, every frame in Performance's Overdrive).
    property Item shared: null
    readonly property bool borrowed: !!shared && shared.sourceItem === viewport
    KeepOut {
        id: content
        sourceItem: root.borrowed ? null : root.viewport
        hideSource: false
        visible: false
    }
    readonly property Item mask: borrowed ? shared : content
    // Drawn at the mask's own resolution into a layer, which is redrawn only when the content or the sky changes and
    // stretched over the room in between: the shadow can't be sharper than its quarter-size mask, so nothing is lost,
    // and its 42 taps run on a sixteenth of the pixels (docs/OVERDRIVE.md §9, 10 November: the sundial was the
    // largest single GPU cost in every room).
    ShaderEffect {
        anchors.fill: parent
        visible: !!root.light && root.cast.length > 0.5
        layer.enabled: true
        layer.smooth: true
        layer.textureSize: root.mask.textureSize
        property var mask: root.mask
        property point offset: Qt.point(root.cast.x / Math.max(1, width), root.cast.y / Math.max(1, height))
        property real strength: root.light?.strength ?? 0
        property color wash: Qt.alpha(S.tint(root.light), 0.11 * (root.light?.strength ?? 0))
        fragmentShader: Qt.resolvedUrl("shaders/sundial.frag.qsb")
    }
}
