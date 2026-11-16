import QtQuick
import Quickshell
import qs.adapters.common
import qs.view.contract
import "DmsWallpaperMap.js" as WallpaperMap

// WallpaperDomain for the ZÆTHERION session (Z178). DMS draws the wallpaper; we read its session.json, read-only and
// watched, and set through DMS's own IPC, so DMS stays the one writer of its files. Usable only while DMS is up.
// DMS's one-wallpaper-per-screen mode is covered (Z210): set() then sets every screen, so perScreen stays false.
WallpaperDomain {
    id: root
    required property DmsLink link
    readonly property string home: Quickshell.env("HOME") ?? ""
    readonly property string sessionPath: (Quickshell.env("XDG_STATE_HOME") || home + "/.local/state") + "/dms/session.json"
    readonly property var screenNames: Quickshell.screens.map(screen => screen.name)
    property string sessionText: ""
    readonly property var state: WallpaperMap.fromSession(sessionText, screenNames)
    available: link.ready
    current: state.current
    perScreen: false
    error: !link.ready ? "DMS is not running" : ""

    function set(path: string) {
        if (!link.ready || !path.startsWith("/"))
            return;
        for (const argv of WallpaperMap.setCommands(path, state.perScreen, screenNames))
            Quickshell.execDetached(argv);
    }
    WatchedFile {
        path: root.sessionPath
        onContentChanged: root.sessionText = content
    }
}
