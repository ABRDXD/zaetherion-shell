import QtQuick
import Quickshell.Hyprland

// Super+V for quick paste (S3, Z182): Hyprland's global shortcut `zaetherion:clips`, delivered to this process with
// nothing started (`qs ipc call island clips` is the fallback). The one place a global shortcut is claimed; only the
// island's process makes one.
GlobalShortcut {
    appid: "zaetherion"
    name: "clips"
    description: "Quick paste from the island"
}
