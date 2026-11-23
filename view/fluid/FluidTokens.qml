pragma Singleton
import QtQuick
import Quickshell
import qs.view.ui

// Fluid keeps its geometry and typeface. Both forms use the Reading first scale.
Singleton {
    readonly property int unit: 4
    readonly property int gap: 16
    readonly property int sectionGap: 32
    readonly property int controlHeight: 34
    readonly property int controlRadius: 8
    readonly property int imageRadius: 18
    readonly property int body: Design.body
    readonly property int caption: Design.caption
    readonly property int title: Design.headline
    readonly property int clock: Design.display
    readonly property int heading: Design.readout
    readonly property int lyric: 24
    readonly property int lyricEmphasis: 30
    readonly property string sans: "Inter"
    readonly property color base: Design.background
    readonly property color ink: Design.ink
    readonly property color secondary: Design.muted
    readonly property color accent: Design.accent
    readonly property color rule: Design.line
    readonly property color control: Design.hover
}
