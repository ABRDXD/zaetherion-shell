// Suspend, reboot and power-off are never called by FART: open the host's power surface instead.
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
}
