import QtQuick
import Quickshell
import qs.adapters.common
import qs.view.contract
import "DmsThemeMap.js" as ThemeMap

// HostThemeDomain for the ZÆTHERION session (Z180): DMS's settings.json read-only and watched; switching goes
// through DMS's own `settings set` IPC (DmsThemeMap.js), so DMS stays the one writer of its file.
HostThemeDomain {
    id: root
    required property DmsLink link
    readonly property string configDir: Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") ?? "") + "/.config"
    available: link.ready
    error: link.ready ? "" : "DMS is not running"

    // Two DMS settings sets, in order (DmsThemeMap.js); a second set() while they run is ignored.
    function set(id: string) {
        if (link.ready)
            runner.run(ThemeMap.setCommands(configDir, id));
    }
    CommandQueue { id: runner }
    WatchedFile {
        path: root.configDir + "/dms/settings.json"
        onContentChanged: root.current = ThemeMap.currentFrom(content)
    }
}
