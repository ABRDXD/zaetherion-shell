// The session card (Z158) grows from the island and calls lock, suspend, logout, reboot and powerOff, each
// confirmed by the owner (lock on a click, the rest on a 1 s hold). Nothing else in FART calls them.
HostDomain {
    property var battery: ({ available: false, level: 0, charging: false, pluggedIn: true })
    property string profile: ""
    property var profiles: []
    property bool idleInhibited: false
    // Lease "brightness": level 0..1.
    property var brightness: ({ available: false, level: 0 })
    property bool nightLight: false

    function setProfile(name: string) { record("setProfile", [name]); }
    function setIdleInhibited(on: bool) { record("setIdleInhibited", [on]); }
    function setBrightness(level: real) { record("setBrightness", [level]); }
    function setNightLight(on: bool) { record("setNightLight", [on]); }
    function lock() { record("lock", []); }
    function suspend() { record("suspend", []); }
    function logout() { record("logout", []); }
    function reboot() { record("reboot", []); }
    function powerOff() { record("powerOff", []); }
}
