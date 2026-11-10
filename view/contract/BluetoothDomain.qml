// BtDevice: { id, name, kind, connected, paired, battery } (battery -1 = unknown).
HostDomain {
    property bool enabled: false
    property var devices: []
    property var primary: null

    function setEnabled(on: bool) { record("setEnabled", [on]); }
    function connect(id: string) { record("connect", [id]); }
    function disconnect(id: string) { record("disconnect", [id]); }
}
