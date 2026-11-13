pragma Singleton
import QtQuick
import Quickshell
import qs.view.ui

// Fluid geometry and type are independent of Angular; all colours use the shared palette.
Singleton {
    readonly property int unit: 4
    readonly property int gap: 16
    readonly property int sectionGap: 32
    readonly property int controlHeight: 34
    readonly property int controlRadius: 8
    readonly property int imageRadius: 18
    readonly property int body: 14
    readonly property int caption: 12
    readonly property int title: 32
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
