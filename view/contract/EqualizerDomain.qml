// The host's own equaliser. FART never runs a second filter chain.
HostDomain {
    property var bands: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    readonly property var frequencies: [31, 63, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]
    readonly property int minGain: -12
    readonly property int maxGain: 12
    property string preset: "Flat"
    property var presets: []
    property real balance: 0
    property bool mono: false
    property bool swap: false
    property bool dynamicEq: false
    property string dynamics: "off"
    property bool pending: false

    function setBand(index: int, gain: int) { record("setBand", [index, gain]); }
    function applyPreset(name: string) { record("applyPreset", [name]); }
    function setBalance(value: real) { record("setBalance", [value]); }
    function setFlag(name: string, on: bool) { record("setFlag", [name, on]); }
    function setDynamics(mode: string) { record("setDynamics", [mode]); }
    function resetAudio() { record("resetAudio", []); }
    function openHost() { record("openHost", []); }
}
