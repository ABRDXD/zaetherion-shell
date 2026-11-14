import QtQuick
import Quickshell.Hyprland

// The paste keystroke for quick paste (S3): Hyprland sends Ctrl+V (Ctrl+Shift+V into a terminal) to the window that
// has the keyboard. Compositor-native, so no virtual-keyboard program and nothing of DMS's clipboard service, whose
// history stays off (F2-4). The terminal rule is DMS's ClipboardService.isTerminalFocused (MIT, see NOTICE).
QtObject {
    id: root
    // The focused window's app id, from the session's workspaces domain.
    property string focusedAppId: ""
    readonly property var terminalIds: ["kitty", "foot", "footclient", "alacritty", "st", "org.wezfurlong.wezterm",
        "com.mitchellh.ghostty", "ghostty", "org.kde.konsole", "konsole", "org.gnome.terminal", "gnome-terminal-server",
        "org.gnome.console", "kgx", "com.gexperts.tilix", "tilix", "terminator", "xfce4-terminal", "lxterminal",
        "deepin-terminal", "io.elementary.terminal", "rio", "contour", "wayst", "urxvt", "rxvt"]
    function terminalFocused(): bool {
        const appId = focusedAppId.toLowerCase();
        return appId !== "" && (terminalIds.includes(appId) || appId.endsWith("term") || appId.includes("terminal"));
    }
    function paste(terminal: bool): void {
        Hyprland.dispatch('hl.dsp.send_shortcut({ mods = "' + (terminal ? "CTRL SHIFT" : "CTRL") + '", key = "V" })');
    }
}
