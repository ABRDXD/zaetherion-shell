pragma Singleton
import QtQuick
import Quickshell

// A · Viewfinder, the owner's pick for choosing a recording area over the live desktop (22 November 2026).
// Values are Astra's study: tools/record-picker-study/index.html on codex/record-picker.
Singleton {
    readonly property color coral: "#ff9b85"
    readonly property color ink: "#151719"
    readonly property color paper: "#f4f1e8"
    readonly property color shade: "#11171e"
    readonly property real shadeOpacity: 0x70 / 255 // only during a drag; the centre stays live
    readonly property color ring: "#24191b" // 2 px just outside the area, under the 1 px white edge
    readonly property int ringWidth: 2
    readonly property color edge: "white"
    readonly property int edgeWidth: 1
    readonly property int cornerLength: 22
    readonly property int cornerWidth: 4
    readonly property int sizeMargin: 7 // between the size tab and the area
    readonly property int sizePadX: 10
    readonly property int sizePadY: 5
    readonly property color hint: "#16191d"
    readonly property color hintSmall: "#d5d7d7"
    readonly property int hintMargin: 16 // from the screen's bottom (or top) edge
    readonly property int hintPadX: 16
    readonly property int hintPadY: 10
    readonly property int hintGap: 18
    readonly property real tagSpacing: 0.77 // 0.07 em of the 11 px tag
}
