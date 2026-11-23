import QtQuick
import Quickshell
import Quickshell.Io
import qs.view.contract

// The ways in to the launcher (S6), for every shell entry: the host's apps key (KeybindsDomain.appsPressed, a
// Hyprland global shortcut with FART_LAUNCHER_SHORTCUT=1) and `qs -p <entry> ipc call launcher toggle`.
// The launcher grows from the island, so an open FART folds first: open, it covers the island.
Scope {
    id: root
    required property KeybindsDomain keybinds
    property var island: null
    property bool panelOpen: false
    // tools/launcher_keycheck.py, path C (FART_COLD_PROBE=1 only): when the key arrived, wall-clock ms.
    readonly property bool probe: Quickshell.env("FART_COLD_PROBE") === "1"
    function toggle(): void {
        if (probe) console.log("FART_COLD", "command", Date.now());
        if (panelOpen) Host.close();
        island?.toggleLauncher();
    }
    Connections {
        target: root.keybinds
        function onAppsPressed() { root.toggle(); }
    }
    IpcHandler {
        target: "launcher"
        function toggle(): void { root.toggle(); }
    }
}
