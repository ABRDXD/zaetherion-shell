import QtQuick
import qs.adapters.quickshell
import "DmsBrightnessMap.js" as BrightnessMap

// The OSD in the ZÆTHERION session: volume and mic from Pipewire (QuickshellOsd), brightness from DMS's
// `brightness` service, which pushes a snapshot on every change, whoever made it (a key, DMS's UI, `dms ipc`).
// Like network (§3), this feed is held for as long as the object exists: the island must show a key press.
QuickshellOsd {
    id: root
    required property DmsLink link
    readonly property DmsFeed brightness: DmsFeed { link: root.link; service: "brightness"; capability: "brightness"; wanted: true }
    // The snapshot is the baseline (and after a reconnect, a new one); each update is one change.
    readonly property var brightnessData: brightness.data
    readonly property var brightnessUpdate: brightness.update
    onBrightnessDataChanged: offerBrightness(brightnessData)
    onBrightnessUpdateChanged: offerBrightness(brightnessUpdate)
    function offerBrightness(data) {
        const s = BrightnessMap.sample(data);
        if (s)
            root.offer(s);
    }
}
