import Quickshell
import Quickshell.Hyprland

// Super+V for quick paste (S3, Z182): Hyprland's global shortcut `zaetherion:clips`, bound with
// `hl.dsp.global("zaetherion:clips")`, reaches this process with nothing started (`qs ipc call island clips` is the
// fallback). One of the two files that may hold a GlobalShortcut (tests/test_layout.py), and off unless the island
// lives in this process.
Scope {
    id: root
    property bool enabled: false
    signal pressed()
    LazyLoader {
        active: root.enabled
        GlobalShortcut {
            appid: "zaetherion"
            name: "clips"
            description: "ZÆTHERION: quick paste from the island"
            onPressed: root.pressed()
        }
    }
}
