import QtQuick
import qs.adapters.common
import qs.core.client
import qs.view.contract
import "DeferredCreate.js" as DeferredCreate

// Serpantinum 2.4.1. The only place in FART that knows this host's commands, files and settings.
HostAdapter {
    id: root
    // The notification mirror lives in the core.
    required property CoreClient core
    readonly property SerpantinumSettings settings: SerpantinumSettings {}
    name: "serpantinum"
    media: SerpantinumMedia {}
    // audio, bluetooth, notifications, lyrics and clipboard: loadDeferred() below.
    network: SerpantinumNetwork {}
    workspaces: SerpantinumWorkspaces {}
    keybinds: SerpantinumKeybinds {}
    power: SerpantinumPower { settings: root.settings }
    palette: SerpantinumPalette { settings: root.settings }
    motion: SerpantinumMotion {}
    hostActions: SerpantinumHostActions {}
    sfx: SerpantinumSfx { settings: root.settings }
    clockGeometry: SerpantinumClockGeometry { settings: root.settings; workspaces: root.workspaces }
    system: LinuxSystem {}

    // Nothing on the panel's first frame shows these five (Devices, Media's lyrics, Clips and Inbox
    // do), so they load by URL when the view asks, after the first open has settled, instead of
    // compiling on every cold start (docs/COLDSTART.md). Until then each is its contract placeholder,
    // which reads "unavailable"; HostLease and the core's host calls follow the swap.
    property bool deferredRequested: false
    function loadDeferred() {
        if (deferredRequested)
            return;
        deferredRequested = true;
        create("SerpantinumEqualizer.qml", { settings: root.settings },
               equalizer => create("SerpantinumAudio.qml", { equalizer: equalizer }, domain => root.audio = domain));
        create("SerpantinumBluetooth.qml", {}, domain => root.bluetooth = domain);
        create("SerpantinumNotifications.qml", { settings: root.settings, core: root.core }, domain => root.notifications = domain);
        create("../common/LyricsSource.qml", { media: root.media, hostCacheDir: root.settings.cacheDir + "/lyrics" },
               domain => root.lyrics = domain);
        create("../common/CliphistClipboard.qml", {}, domain => root.clipboard = domain);
    }
    function create(file, properties, done) {
        DeferredCreate.create(root, Qt.resolvedUrl(file), properties, done, "serpantinum:");
    }
}
