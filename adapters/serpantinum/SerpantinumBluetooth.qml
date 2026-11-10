import QtQuick
import Quickshell
import Quickshell.Bluetooth
import qs.view.contract

BluetoothDomain {
    id: root
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property var raw: Bluetooth.devices.values.filter(d => d.paired || d.connected)
    function find(id) { return raw.find(d => d.address === id) ?? null; }
    available: adapter !== null
    enabled: adapter?.enabled ?? false
    devices: raw.map(d => ({ id: d.address, name: d.name || d.deviceName || d.address, kind: d.icon ?? "",
        connected: d.connected, paired: d.paired, battery: d.batteryAvailable ? d.battery : -1 }))
    primary: devices.find(d => d.connected) ?? null

    function setEnabled(on: bool) { if (adapter) adapter.enabled = on; }
    function connect(id: string) { const d = find(id); if (d?.paired && !d.connected) d.connect(); }
    function disconnect(id: string) { const d = find(id); if (d?.connected) d.disconnect(); }
}
