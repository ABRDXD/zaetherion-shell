// The desktop wallpaper the host draws (Z177). The host is the authority for what is applied; FART's core keeps the
// folder, recent choices and the preview. current is an absolute file path, or "" when the host shows a plain colour
// or nothing. perScreen: the host keeps one wallpaper per screen, which set() does not cover yet. error says why
// set() can't work now ("" when it can).
HostDomain {
    property string current: ""
    property bool perScreen: false
    property string error: ""
    function set(path: string) { record("set", [path]); }
}
