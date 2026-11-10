// Lease "lyrics". LyricLine: { time, end, text, words: [{ time, end, text }] }, seconds.
// status: idle | loading | ok | none | no-track. source: host-cache | fart-cache | fetch | local.
HostDomain {
    property string status: "idle"
    property string source: ""
    property string trackKey: ""
    property var lines: []
    property bool wordTimed: false

    function reload() { record("reload", []); }
    function loadLocal(path: string) { record("loadLocal", [path]); }
}
