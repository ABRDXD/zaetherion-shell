// A keybind: { mods: ["SUPER", "SHIFT"], key: "S" (the compositor's name), section: "Utilities", description: "Screen snip" }.
// mods holds any of SUPER, SHIFT, CTRL, ALT, in that order. Only binds the host describes are listed.
HostDomain {
    property var capsLock: null
    property var numLock: null
    property var binds: []
    function refresh() { record("refresh", []); }
}
