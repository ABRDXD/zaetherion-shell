import Quickshell
import Quickshell.Hyprland

// The launcher key as a Hyprland global shortcut (docs/S6_LAUNCHER.md §2, option B): bound with
// `hl.dsp.global("zaetherion:launcher")`, it reaches this process directly, with no CLI spawn or core round trip.
// The only file that may hold a GlobalShortcut (tests/test_layout.py), and off unless asked.
Scope {
    id: root
    property bool enabled: false
    signal pressed()
    signal released()
    signal appsPressed()
    LazyLoader {
        active: root.enabled
        GlobalShortcut {
            appid: "zaetherion"
            name: "launcher"
            description: "ZÆTHERION: command line (hold to ignite)"
            onPressed: root.pressed()
            onReleased: root.released()
        }
    }
    LazyLoader {
        active: root.enabled
        GlobalShortcut {
            appid: "zaetherion"
            name: "apps"
            description: "ZÆTHERION: launcher"
            onPressed: root.appsPressed()
        }
    }
}
