import QtQuick
import qs.adapters.hyprland

// Keybinds for the ZÆTHERION session: the binds from Hyprland, caps and num lock from DMS's `evdev` service (Z24:
// they show in the island's hover view). Held for as long as this object exists, like network (§3): DMS sends one
// small snapshot when a lock key changes. null until the first snapshot, so nothing reads "off" early.
HyprlandKeybinds {
    id: root
    required property DmsLink link
    readonly property DmsFeed locks: DmsFeed { link: root.link; service: "evdev"; capability: "evdev"; wanted: true }
    readonly property var lockData: locks.data
    capsLock: lockData?.available === true && typeof lockData.capsLock === "boolean" ? lockData.capsLock : null
    numLock: lockData?.available === true && typeof lockData.numLock === "boolean" ? lockData.numLock : null
}
