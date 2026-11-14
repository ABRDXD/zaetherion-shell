import QtQuick
import Quickshell.Hyprland
import "HyprlandExec.js" as HyprlandExec

// Starts a program through Hyprland, as a keybind would (HyprlandExec.js says why).
QtObject {
    function run(argv: var, workingDirectory: string) {
        if (argv && argv.length > 0)
            Hyprland.dispatch(HyprlandExec.dispatch(argv, workingDirectory));
    }
}
