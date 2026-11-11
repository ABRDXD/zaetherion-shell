pragma Singleton
import qs.view.contract
import qs.view.shell
import QtQuick
import Quickshell

Singleton {
    id: root
    // The entry file injects the host palette once; until then every token uses its fallback.
    property PaletteDomain source: null
    // A copy, refreshed on change, so tokens never re-evaluate against a palette being destroyed.
    property var theme: ({ colors: {} })
    readonly property var palette: theme.colors
    function refresh() {
        if (source) theme = { colors: source.colors ?? {}, opacity: source.opacity, radius: source.radius, blur: source.blur, mono: source.monoFamily };
    }
    // Assigned, not bound: bindings would re-run against a dying context at shutdown.
    onSourceChanged: { sourceChanges.target = source; refresh(); }
    property Connections sourceChanges: Connections {
        id: sourceChanges
        target: null
        function onColorsChanged() { root.refresh(); }
        function onOpacityChanged() { root.refresh(); }
        function onRadiusChanged() { root.refresh(); }
        function onBlurChanged() { root.refresh(); }
        function onMonoFamilyChanged() { root.refresh(); }
    }
    readonly property color background: palette.background ?? "#0d1218"
    readonly property color surface: palette.surface ?? "#151c24"
    readonly property color hover: palette.surfaceRaised ?? "#202b36"
    readonly property color ink: palette.text ?? "#edf0ed"
    readonly property color muted: palette.textMuted ?? "#b5c0c9"
    readonly property color faint: palette.textFaint ?? "#9aa9b5"
    readonly property color line: palette.line ?? "#4b5b67"
    readonly property color accent: palette.accent ?? "#a5cfdf"
    readonly property color warm: palette.warm ?? "#f4bc62"
    readonly property color warning: warm
    readonly property color danger: palette.danger ?? "#ff4b55"
    readonly property color recording: danger
    readonly property color selected: palette.highlight ?? ink
    readonly property color mediaAccent: palette.highlight ?? ink
    readonly property color calendarAccent: palette.warm ?? ink
    readonly property color buttonSurface: palette.surface ?? "transparent"
    readonly property color portraitText: palette.text ?? "#f5f6f2"
    readonly property color portraitDetail: palette.textMuted ?? "#ced9df"
    readonly property color success: palette.success ?? "#a7d8b5"
    readonly property color islandFill: darkestIslandRole(palette)

    function linearChannel(value: real): real {
        return value <= 0.04045 ? value / 12.92 : Math.pow((value + 0.055) / 1.055, 2.4);
    }

    function darkestIslandRole(colors: var): color {
        let darkest = background;
        let darkestBlue = null;
        let low = Infinity;
        let lowBlue = Infinity;
        for (const value of Object.values(colors)) {
            const candidate = Qt.color(value);
            const luminance = 0.2126 * linearChannel(candidate.r)
                            + 0.7152 * linearChannel(candidate.g)
                            + 0.0722 * linearChannel(candidate.b);
            const hue = candidate.hslHue * 360;
            if (luminance < low) {
                darkest = candidate;
                low = luminance;
            }
            // The blue sector used in the approved study, excluding neutral colours.
            if (hue >= 195 && hue <= 260 && luminance < lowBlue) {
                darkestBlue = candidate;
                lowBlue = luminance;
            }
        }
        return darkestBlue ?? darkest;
    }

    readonly property real panelOpacity: theme.opacity ?? 0.94
    readonly property int radiusPanel: theme.radius ?? 24
    readonly property bool blur: theme.blur ?? false
    readonly property int radiusSmall: 0
    readonly property int radiusControl: 1
    readonly property int radiusCard: 2
    // Type scale (MONTAGE.md §2). Rooms use these tokens only; tests/test_layout.py enforces it.
    readonly property int caption: 11
    readonly property int body: 12
    readonly property int control: 13
    readonly property int readout: 20
    readonly property int figure: 32 // secondary numerals and the logo
    readonly property int headline: 52
    readonly property int display: 86 // hero numerals and glyphs
    readonly property string sans: "Roboto Condensed"
    readonly property string mono: theme.mono ?? "JetBrains Mono Nerd Font"
    readonly property bool geometric: Config.options.appearance.geometric
    readonly property bool italic: Config.options.appearance.fonts.italicMain
    // The one angle family: −12° shear and its 78° perpendicular. No other angle in rooms.
    readonly property real shear: -0.21255656 // tan(-12 degrees)
    readonly property real slope: 4.70463011 // tan(78 degrees)
    readonly property int baseline: 4
    readonly property int minHit: 24
}
