import Quickshell
import Quickshell.Io

// Serpantinum's settings.json, read-only. Private to this adapter.
Scope {
    id: root
    readonly property string home: Quickshell.env("HOME")
    readonly property string configDir: (Quickshell.env("XDG_CONFIG_HOME") || home + "/.config") + "/serpantinum"
    readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || home + "/.local/state") + "/serpantinum"
    readonly property string cacheDir: (Quickshell.env("XDG_CACHE_HOME") || home + "/.cache") + "/serpantinum"
    readonly property string runDir: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/serpantinum"
    readonly property string sourceDir: (Quickshell.env("SERPANTINUM_DIR") || home + "/.local/share/serpantinum/src") + "/quickshell"
    property var values: ({})
    FileView {
        path: root.configDir + "/settings.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: { try { root.values = JSON.parse(text()); } catch (_) {} }
    }
}
