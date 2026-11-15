import QtQuick
import Quickshell
import qs.adapters.common
import qs.view.contract
import "DmsWallpaperMap.js" as WallpaperMap

// WallpaperDomain for the ZÆTHERION session (Z178). DMS draws the wallpaper; we read its session.json, read-only and
// watched, and set through DMS's own IPC, so DMS stays the one writer of its files. Usable only while DMS is up.
WallpaperDomain {
    id: root
    required property DmsLink link
    readonly property string home: Quickshell.env("HOME") ?? ""
    readonly property string sessionPath: (Quickshell.env("XDG_STATE_HOME") || home + "/.local/state") + "/dms/session.json"
    property var state: ({ current: "", perScreen: false })
    available: link.ready
    current: state.current
    perScreen: state.perScreen
    error: !link.ready ? "DMS is not running" : state.perScreen ? "DMS sets a wallpaper per screen" : ""

    function set(path: string) {
        if (!link.ready || state.perScreen || !path.startsWith("/"))
            return;
        Quickshell.execDetached(WallpaperMap.setCommand(path));
    }
    WatchedFile {
        path: root.sessionPath
        onContentChanged: root.state = WallpaperMap.fromSession(content)
    }
}
