import QtQuick
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
    readonly property DmsLink dms: DmsLink { id: link; clientId: "zaetherion-" + root.role }
    name: "dms"
    media: QuickshellMedia {}
    network: DmsNetwork {
        link: link
        // Passwords live in settings (Z95).
        onUnknownNetwork: root.hostActions.open("wifi")
    }
    // audio, notifications, lyrics and clipboard: loadDeferred() below.
    workspaces: HyprlandWorkspaces {}
    keybinds: HyprlandKeybinds {}
    power: DmsPower {}
    tray: QuickshellTray {}
    system: LinuxSystem {}

    // Nothing on the panel's first frame shows these four, so they load when the view asks, after the first open
    // has settled (docs/COLDSTART.md). Until then each is its contract placeholder, which reads "unavailable".
    property bool deferredRequested: false
    function loadDeferred() {
        if (deferredRequested)
            return;
        deferredRequested = true;
        create("../quickshell/QuickshellAudio.qml", {}, domain => root.audio = domain);
        create("DmsNotifications.qml", { core: root.core }, domain => root.notifications = domain);
        create("../common/LyricsSource.qml", { media: root.media }, domain => root.lyrics = domain);
        create("../common/CliphistClipboard.qml", {}, domain => root.clipboard = domain);
    }
    function create(file, properties, done) {
        DeferredCreate.create(root, Qt.resolvedUrl(file), properties, done, "dms:");
    }
}
