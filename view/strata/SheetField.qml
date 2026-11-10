import qs.view.cues
import qs.view.ui
import QtQuick

// The room sheet alive (docs/OVERDRIVE.md §4, the hero for every room), a stratum and the keep-out mask's first
// user: a drifting moiré of two hatch fields on the sheet, under the room's content, kept clear of it by KeepOut
// and off the title wedge. `content` is the room's live content (the mask's source) and `contentRect` where it
// sits on this item; `wedgeRect` the wedge, in this item's coordinates.
ShaderEffect {
    id: root
    property Item content: null
    property rect contentRect: Qt.rect(0, 0, 0, 0)
    property rect wedgeRect: Qt.rect(0, 0, 0, 0)
    property real phaseValue: 0
    property real bassLevel: 0
    property point pointerAt: Qt.point(-1000, -1000)
    property real lightLevel: 0
    KeepOut {
        id: keepOut
        sourceItem: root.content
        visible: false
    }
    property var mask: keepOut
    blending: true
    fragmentShader: Qt.resolvedUrl("shaders/sheet.frag.qsb")
    readonly property vector2d size: Qt.vector2d(width, height)
    readonly property real phase: phaseValue
    readonly property real alive: Motion.drive
    readonly property real bass: bassLevel
    readonly property real light: lightLevel
    readonly property vector2d pointer: Qt.vector2d(pointerAt.x, pointerAt.y)
    readonly property vector4d contentBox: Qt.vector4d(contentRect.x, contentRect.y, contentRect.width, contentRect.height)
    readonly property vector4d wedge: Qt.vector4d(wedgeRect.x, wedgeRect.y, wedgeRect.width, wedgeRect.height)
    readonly property color lineColor: Qt.alpha(Design.line, 0.55)
    readonly property color glowColor: Design.accent
}
