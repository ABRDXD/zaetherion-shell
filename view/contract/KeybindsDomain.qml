// A keybind: { mods: ["SUPER", "SHIFT"], key: "S" (the compositor's name), section: "Utilities", description: "Screen snip" }.
// mods holds any of SUPER, SHIFT, CTRL, ALT, in that order. Only binds the host describes are listed.
HostDomain {
    property var capsLock: null
    property var numLock: null
    property var binds: []
    function refresh() { record("refresh", []); }
    // The launcher key's edges, when the host delivers it to this process (docs/S6_LAUNCHER.md §2, option B).
    signal launcherPressed()
    signal launcherReleased()
    // The apps launcher key (Super tap, Super+Space; Z26), the same way, when the host delivers it.
    signal appsPressed()
}
