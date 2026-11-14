import QtQuick
import Quickshell
import Quickshell.Io
import qs.view.contract
import "DmsThemeMap.js" as ThemeMap

// HostThemeDomain for the ZÆTHERION session (Z180): DMS's settings.json read-only and watched; switching goes
// through DMS's own `settings set` IPC (DmsThemeMap.js), so DMS stays the one writer of its file.
HostThemeDomain {
    id: root
    required property DmsLink link
    readonly property string configDir: Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") ?? "") + "/.config"
    property var queue: []
    available: link.ready
    error: link.ready ? "" : "DMS is not running"

    function set(id: string) {
        if (!link.ready || runner.running)
            return;
        queue = ThemeMap.setCommands(configDir, id);
        next();
    }
    function next() {
        if (!queue.length)
            return;
        runner.command = queue[0];
        queue = queue.slice(1);
        runner.running = true;
    }
    Process {
        id: runner
        onExited: (code, status) => { if (code === 0) root.next(); else root.queue = []; }
    }
    FileView {
        path: root.configDir + "/dms/settings.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.current = ThemeMap.currentFrom(text())
        onLoadFailed: root.current = ""
    }
}
