import QtQuick

// The control keep-out mask (D12, docs/OVERDRIVE.md §4): the panel's own content, drawn small into a texture, so a
// stratum's shader can fade itself out wherever a control, a plane or text is drawn (its alpha) and keep to the
// negative space. A quarter of the size, so the mask is soft and a little wider than what it keeps clear.
// Only a stratum creates one, so it exists only in Overdrive. Never put the stratum inside `sourceItem`.
// Redrawn at most `rate` times a second, and live only while the source scrolls: a room with an animation of its
// own (Performance's rain, Home's sky) otherwise drew itself a second time on every frame, to keep a soft mask a
// frame fresher than anyone can see (docs/OVERDRIVE.md §9, the 10 November pass).
ShaderEffectSource {
    id: root
    property real resolution: 0.25
    property int rate: 15
    readonly property bool moving: !!sourceItem && sourceItem.moving === true
    live: moving
    hideSource: false
    recursive: false
    smooth: true
    textureSize: Qt.size(Math.max(1, Math.round((sourceItem?.width ?? 1) * resolution)),
                         Math.max(1, Math.round((sourceItem?.height ?? 1) * resolution)))
    Timer {
        interval: Math.round(1000 / Math.max(1, root.rate))
        repeat: true
        running: !!root.sourceItem && !root.moving
        triggeredOnStart: true
        onTriggered: root.scheduleUpdate()
    }
}
