// Host surfaces and one-off host actions. Opening a host surface is the view's cue to close FART.
// Targets: launcher, clipboard, settings, themes, wallpapers, wifi, bluetooth, notifications,
// power, display, music, calendar, updates.
HostDomain {
    property string name: ""
    property string version: ""
    property var targets: []
    property bool launcherAcceptsQuery: false
    property var updates: ({ available: false, checking: false, count: 0 })
    // Lease "recording": status probe; startedAt in epoch seconds.
    property var recording: ({ available: false, active: false, startedAt: 0 })

    function open(target: string) { record("open", [target]); }
    function openLauncher(query: string) { record("openLauncher", [query]); }
    function checkUpdates() { record("checkUpdates", []); }
    function capture() { record("capture", []); }
    function setRecording(on: bool) { record("setRecording", [on]); }
}
