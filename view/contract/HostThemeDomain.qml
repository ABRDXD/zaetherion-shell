// The host desktop's own theme (Z180), for presets only: current is the host's theme id ("" unknown); set(id)
// switches the host to one of its installed themes. FART's own colours stay the palette domain's and the core's.
HostDomain {
    property string current: ""
    property string error: ""
    function set(id: string) { record("set", [id]); }
}
