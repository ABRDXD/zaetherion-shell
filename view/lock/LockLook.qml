import QtQuick
import qs.view.ui

// The lock's colours and type (Astra's PasswordLockFace). Since 24 Nov every colour comes from the theme (owner:
// "the colours aren't derived from the theme"): ink, accent, alert and the hairline are the palette's; the plates
// are the island's dark, tinted with the accent; text on the accent picks dark or light by luminance.
QtObject {
    required property bool fluid
    readonly property color ink: Design.ink
    readonly property color accent: Design.accent
    readonly property color alert: Qt.tint(Design.danger, Qt.alpha(Design.ink, 0.45))  // the palette's danger, lifted to read on the dark
    readonly property color muted: Design.muted
    readonly property color line: Design.line
    readonly property color base: Design.islandFill
    readonly property color plateDeep: Qt.tint(base, Qt.alpha(accent, 0.05))
    readonly property color plate: Qt.tint(base, Qt.alpha(accent, 0.10))
    readonly property color plateRaised: Qt.tint(base, Qt.alpha(accent, 0.22))
    readonly property color alertPlate: Qt.tint(base, Qt.alpha(Design.danger, 0.18))
    readonly property color paper: Qt.tint(ink, Qt.alpha(accent, 0.12))
    readonly property color onPaper: base
    readonly property color onAccent: readable(accent)
    function readable(c) {
        const lin = v => v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4);
        const l = 0.2126 * lin(c.r) + 0.7152 * lin(c.g) + 0.0722 * lin(c.b);
        return l > 0.22 ? "#25232f" : "#f3efdc";
    }
    readonly property int small: 13
    readonly property int body: 18
    readonly property int track: 21
    readonly property int dateSize: fluid ? 24 : 22
    readonly property int clockSize: fluid ? 115 : 127
}
