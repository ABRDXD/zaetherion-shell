import QtQuick
import Quickshell
import qs.adapters.common
import qs.adapters.hyprland
import qs.adapters.quickshell
import qs.core.client
import qs.view.contract
import "DeferredCreate.js" as DeferredCreate

// The HostAdapter of the ZÆTHERION session on DMS (docs/DMS_ADAPTER.md §0). One per process: the resident and
// the panel each create their own, with their own connections and leases. Only adapters know DMS.
HostAdapter {
    id: root
    // The notification mirror lives in the core.
    required property CoreClient core
    // The DMS socket, given by the session (DMS_SOCKET by default, §7). The entry may bind it.
    property alias socketPath: link.socketPath
    // Names this process's subscription in DMS's logs ("zaetherion-shell", "zaetherion-panel").
    property string role: "shell"
    // Where the island lives (shell-dms.qml with ZAETHERION_ISLAND=1): volume and mic changes become OSD events (S5).
    property bool osdWanted: false
    // Where the island lives: quick paste (Super+V) grows from it, so the clipboard is there from the start. It reads
    // nothing until a surface leases "history" (S3; cold start in docs/S3_CLIPS_REST.md).
    property bool clipsWanted: false
    readonly property DmsLink dms: DmsLink { id: link; clientId: "zaetherion-" + root.role }
    name: "dms"
    media: QuickshellMedia {}
    // A new network's password is typed in FART's own settings (Z95, Z176): the view opens them, nothing here does.
    network: DmsNetwork { link: link }
    bluetooth: DmsBluetooth { link: link }
    // audio (with the equaliser), notifications, lyrics and clipboard: loadDeferred() below.
    workspaces: HyprlandWorkspaces {}
    keybinds: DmsKeybinds { link: link }
    power: DmsPower {}
    wallpaper: DmsWallpaper { link: link }
    hostTheme: DmsHostTheme { link: link }
    tray: QuickshellTray {}
    // The launcher's apps (S6): ready at start, since the launcher opens straight from the island (Z139).
    apps: QuickshellApps { spawner: HyprlandSpawner {} }
    // DMS's own launcher engine for the star chart (Z197), through the bridge in the quiet copy.
    launcher: DmsLauncher {}
    system: LinuxSystem {}

    // Nothing on the panel's first frame shows these four, so they load when the view asks, after the first open
    // has settled (docs/COLDSTART.md). Until then each is its contract placeholder, which reads "unavailable".
    property bool deferredRequested: false
    function loadDeferred() {
        if (deferredRequested)
            return;
        deferredRequested = true;
        create("../quickshell/QuickshellAudio.qml", {}, domain => {
            domain.osd = Qt.binding(() => root.osd.hush ? root.osd : null);
            root.audio = domain;
            // Our own equaliser (Z173), run by the core. If it cannot be made, audio keeps the placeholder's.
            create("../common/CoreEqualizer.qml", { core: root.core }, equalizer => domain.equalizer = equalizer);
        });
        if (!serverAtStart)
            createNotifications();
        create("../common/LyricsSource.qml", { media: root.media }, domain => root.lyrics = domain);
        if (!clipsWanted)
            createClipboard();
    }
    // DMS's own clipboard history (Z202): DMS records, pins and sends the paste keystroke. Which window gets it
    // (a terminal takes Ctrl+Shift+V) is read from Hyprland, as DMS reads it from its toplevels.
    readonly property HyprlandPaste pasteKeys: HyprlandPaste {
        focusedAppId: root.workspaces.windows.find(window => window.focused)?.appId ?? ""
    }
    function createClipboard() {
        create("DmsClipboard.qml", {
            link: link,
            terminalFocused: () => root.pasteKeys.terminalFocused()
        }, domain => root.clipboard = domain);
    }
    // With our notification server on (Z169), the notifications domain runs it, so it loads at start: until it
    // does, nobody holds the bus name and notifications sent meanwhile are lost.
    readonly property bool serverAtStart: Quickshell.env("FART_NOTIFICATION_SERVER") === "1"
    function createNotifications() {
        create("DmsNotifications.qml", { core: root.core }, domain => root.notifications = domain);
    }
    // The OSD is at rest with the island (Z138), so it does not wait for the panel's first open.
    Component.onCompleted: {
        if (osdWanted)
            create("DmsOsd.qml", { link: link }, domain => root.osd = domain);
        if (clipsWanted)
            createClipboard();
        if (serverAtStart)
            createNotifications();
    }
    function create(file, properties, done) {
        DeferredCreate.create(root, Qt.resolvedUrl(file), properties, done, "dms:");
    }
}
