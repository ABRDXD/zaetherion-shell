import QtQuick
import Quickshell
import Quickshell.Io
import qs.view.contract

// Host colours (saved preset or Matugen) mapped from Serpantinum's names to neutral roles.
PaletteDomain {
    id: root
    required property var settings
    readonly property var theme: settings.values.theme ?? {}
    readonly property var staticColors: theme.colors ?? theme.palette ?? (theme.base ? theme : {})
    property var savedColors: ({})
    property var generatedColors: ({})
    readonly property var hostColors: theme.matugen === true
        ? Object.assign({}, savedColors, generatedColors)
        : Object.assign({}, savedColors, staticColors)
    readonly property var roles: ({ background: "base", surface: "surface0", surfaceRaised: "surface1", text: "text",
        textMuted: "overlay2", textFaint: "subtext1", line: "overlay0", accent: "blue", warm: "yellow",
        danger: "red", success: "green", highlight: "mauve" })
    readonly property bool liquid: theme.blurBackground === true && theme.blurStyle === "liquid"
    available: true
    colors: {
        const result = {};
        for (const role in roles) if (hostColors[roles[role]] !== undefined) result[role] = hostColors[roles[role]];
        return result;
    }
    onColorsChanged: revision++
    opacity: liquid ? 0.1 : Math.min(1, Math.max(0, (theme.elementOpacity ?? 94) / 100))
    radius: Math.max(0, theme.borderRadius ?? 24)
    blur: theme.blurBackground === true
    monoFamily: theme.fontFamily || "JetBrains Mono Nerd Font"
    function readColors(view, previous) {
        try {
            const data = JSON.parse(view.text());
            const colors = data.colors ?? data;
            if (/^#[0-9a-f]{6}$/i.test(colors.base)) return colors;
        } catch (_) {}
        return previous;
    }
    FileView {
        readonly property string configuredPath: Quickshell.env("QS_COLORS_JSON") || root.settings.stateDir + "/qs_colors.json"
        path: configuredPath.replace(/^~\//, root.settings.home + "/")
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.savedColors = root.readColors(this, root.savedColors)
    }
    FileView {
        path: root.theme.matugen === true ? root.settings.stateDir + "/qs_matugen_colors.json" : ""
        watchChanges: root.theme.matugen === true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.generatedColors = root.readColors(this, root.generatedColors)
        onLoadFailed: root.generatedColors = ({})
    }
}
