import QtQuick
import Quickshell.Bluetooth

// Battery levels of Bluetooth devices (BlueZ's Battery1, through Quickshell), by address. Read-only: it never
// powers, scans, pairs or connects anything. DMS's backend reports no battery (docs/NET_BT.md §1, Z190).
QtObject {
    // address -> 0..1, only for devices that report one.
    readonly property var levels: {
        const out = {};
        for (const d of Bluetooth.devices.values)
            if (d && d.batteryAvailable) out[d.address] = d.battery;
        return out;
    }
    function levelOf(address) { return levels[address] ?? -1; }
}
