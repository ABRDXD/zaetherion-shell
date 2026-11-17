pragma Singleton
import qs.view.contract
import qs.view.shell
import QtQuick
import Quickshell

Singleton {
    id: root
    // Z146: the desktop's form, "angular" or "fluid". Only the island (FARTland) reads it so far; FART stays
    // Angular until FART // Fluid is designed.
    property string form: "angular"
    readonly property bool fluid: form === "fluid"
    // Fluid corner radii: small parts, plates and the island's lower corners.
    readonly property int roundSmall: 6
    readonly property int roundPlate: 10
    readonly property int roundIsland: 14
    // Fluid: the concave curve where the island's sides meet the screen edge.
    readonly property int roundEar: 8
    // Fluid's island icons: "fill" (solid rounded glyphs), "thin" (light rounded outlines) or "plain".
    property string fluidIcons: "fill"
    readonly property real iconFill: fluid && fluidIcons === "fill" ? 1 : 0
    readonly property int iconWeight: fluid && fluidIcons === "thin" ? 300 : 400
    // The entry file injects the host palette once; until then every token uses its fallback.
    property PaletteDomain source: null
    // A copy, refreshed on change, so tokens never re-evaluate against a palette being destroyed.
    property var theme: ({ colors: {} })
    // The core selection overrides host colours; fixtures without a core retain their source.
    property var selection: null
    readonly property var palette: selection ?? theme.colors
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
    // Built-in palette: DMS's Amoled Black theme, black flavour, white accent (owner, 12 November 2026). A host
    // palette overrides any role. The theme's raised surface is also black, so hover is derived from it.
    readonly property color background: palette.background ?? "#000000"
    readonly property color surface: palette.surface ?? "#000000"
    readonly property color hover: palette.surfaceRaised && !Qt.colorEqual(palette.surfaceRaised, surface)
        ? palette.surfaceRaised : Qt.tint(surface, Qt.alpha(ink, 0.10))
    readonly property color ink: palette.text ?? "#e6f0ff"
    readonly property color muted: palette.textMuted ?? "#999999"
    readonly property color faint: palette.textFaint ?? "#999999"
    readonly property color line: palette.line ?? "#555555"
    readonly property color accent: palette.accent ?? "#ffffff"
    readonly property color warm: palette.warm ?? "#ffcc00"
    readonly property color warning: warm
    readonly property color danger: palette.danger ?? "#dd0000"
    readonly property color recording: danger
    readonly property color selected: palette.highlight ?? ink
    readonly property color mediaAccent: palette.highlight ?? ink
    readonly property color calendarAccent: palette.warm ?? ink
    readonly property color buttonSurface: palette.surface ?? "transparent"
    readonly property color portraitText: palette.text ?? "#ffffff"
    readonly property color portraitDetail: palette.textMuted ?? "#999999"
    readonly property color success: palette.success ?? accent
    readonly property color islandFill: palette.islandBackground ?? darkestIslandRole(palette)
    // Astrophysical colours (Z196): physical constants, not theme roles, so they stay the same on every palette.
    // Stars by spectral class, hottest first (blackbody tints O B A F G K M); the launcher colours a result by rank.
    readonly property var spectral: ["#9bb0ff", "#aabfff", "#cad7ff", "#f8f7ff", "#fff4ea", "#ffd2a1", "#ff9f6b"]
    readonly property color pulsar: "#cba6f7"   // FART verbs
    readonly property color comet: "#94e2d5"    // `>cmd`
    readonly property color nebula: "#f5c2e7"   // `?term`
    readonly property color binary: "#f9e2af"   // sums and conversions
    readonly property color asteroid: "#d9b48a" // files (DMS's engine, Z197)
    readonly property color moon: "#dfe7f2"     // DMS settings
    readonly property color quasar: "#7dd3fc"   // DMS plugins
    readonly property color satellite: "#a6e3a1" // clipboard entries
    // The cold far system (Z199): workspaces seen edge-on, and the launcher's planets. Restrained on purpose.
    readonly property color voidFill: "#020406"   // the island's dark while a cold scene shows
    readonly property color coldStar: "#cfe3ff"
    readonly property color coldCore: "#f4f8ff"
    readonly property color coldRim: "#b9cfe6"    // a planet's lit crescent
    readonly property color coldBody: "#05080b"   // a planet's night side
    readonly property color coldLine: "#1b2a33"   // orbits, the scale
    readonly property color coldInk: "#8fa6b4"    // the readout
    readonly property color atmosphere: "#6fb7d6" // a planet's thin air, lit by the disc (Fluid Timers)
    function starColor(rank: int): color { return spectral[Math.max(0, Math.min(rank, spectral.length - 1))]; }

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
    readonly property string mono: theme.mono ?? "JetBrainsMono Nerd Font"
    readonly property bool geometric: Config.options.appearance.geometric
    readonly property bool italic: Config.options.appearance.fonts.italicMain
    // The one angle family: −12° shear and its 78° perpendicular. No other angle in rooms.
    readonly property real shear: -0.21255656 // tan(-12 degrees)
    readonly property real slope: 4.70463011 // tan(78 degrees)
    readonly property int baseline: 4
    readonly property int minHit: 24
}
