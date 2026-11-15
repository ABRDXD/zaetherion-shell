import Quickshell
import Quickshell.Hyprland
import "ShortcutEdges.js" as Edges

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
            // A key bound on release (the Super tap: `release = true`) makes Hyprland send only the release; a plain
            // bind (Super+Space) sends press then release. So a release opens only when no press came before it.
            property bool down: false
            function edge(kind) {
                const next = Edges.edge(down, kind);
                down = next.down;
                if (next.open) root.appsPressed();
            }
            onPressed: edge("pressed")
            onReleased: edge("released")
        }
    }
}
