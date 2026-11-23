pragma Singleton
import QtQuick
import Quickshell

// A · Eclipse, the owner's frozen-selector pick (Z48, 21 November 2026), with A · Pilot light for its other states
// (22 November). Values are Astra's mocks: tools/selector-study/render.py `eclipse()` and states.py. They are fixed, not palette colours, so the crop reads the same
// over any screen.
Singleton {
    readonly property color shade: "#090c10"
    readonly property real shadeOpacity: 0.79
    readonly property color edgeDark: "#161b19"
    readonly property int edgeDarkWidth: 3
    readonly property color edgeLight: "#f7f7ed"
    readonly property int edgeLightWidth: 1
    readonly property color lime: "#d6ff74"
    readonly property color ink: "#151918"
    readonly property color footer: "#101415"
    readonly property color footerText: "#f7f7ed"
    readonly property int cornerLength: 21
    readonly property int cornerWidth: 3
    readonly property int cornerOffset: 3
    readonly property int labelHeight: 26
    readonly property int labelGap: 8 // between the label and the crop's top edge
    readonly property int labelInset: 4 // the label starts this far left of the crop
    readonly property int labelPadding: 10 // the size text starts this far into the label
    readonly property int labelMinWidth: 154 // the mock's label; a longer size widens it
    readonly property int footerHeight: 48
    readonly property int footerMargin: 27
    readonly property int pauseBarWidth: 3
    readonly property int pauseBarHeight: 11
    readonly property int pauseGap: 3
    readonly property int pauseTextGap: 13
    // Pilot light: the cross that is the pointer before a drag (open centre), lime over a dark outline.
    readonly property int reticleArm: 10
    readonly property int reticleGap: 5
    readonly property int reticleWidth: 2
    readonly property int reticleOutline: 4
    // Pilot light: the quiet label on a screen the pointer isn't on.
    readonly property int quietHeight: 30
    readonly property int quietMargin: 16 // from the screen's left edge
    readonly property int quietBottom: 14 // from the screen's bottom edge
    readonly property int quietPadding: 11
    readonly property int quietBarHeight: 10
}
