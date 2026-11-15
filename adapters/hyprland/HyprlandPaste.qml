import QtQuick
import Quickshell.Hyprland

// Is the window that has the keyboard a terminal (Ctrl+Shift+V)? DMS's ClipboardService.isTerminalFocused (MIT, see
// NOTICE). On DMS the keystroke itself is DMS's `clipboard.sendPaste` (Z202) and only the rule is used; paste()
// sends it through Hyprland, for a session whose clipboard history is not DMS's.
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
