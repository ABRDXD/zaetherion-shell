// The ten-band equaliser and the mono switch (Z50, Z173). Gains are whole dB at `frequencies`.
// enabled is the owner's switch; active means the chain is in the audio path right now.
HostDomain {
    property bool enabled: false
    property bool active: false
    // Why it is not active while enabled ("" when nothing is wrong).
    property string error: ""
    property var bands: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    readonly property var frequencies: [31, 63, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]
    readonly property int minGain: -12
    readonly property int maxGain: 12
    property string preset: "Flat"
    property var presets: []
    property bool mono: false

    function setEnabled(on: bool) { record("setEnabled", [on]); }
    function setBand(index: int, gain: int) { record("setBand", [index, gain]); }
    function applyPreset(name: string) { record("applyPreset", [name]); }
    function setMono(on: bool) { record("setMono", [on]); }
}
