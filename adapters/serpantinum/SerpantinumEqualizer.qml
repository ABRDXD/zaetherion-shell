import QtQuick
import Quickshell
import Quickshell.Io
import qs.view.contract

// Drives the host's own equaliser through its script; the state file is the source of truth.
EqualizerDomain {
    id: root
    required property var settings
    readonly property string script: settings.sourceDir + "/media/equalizer.sh"
    property bool scriptFound: false
    property bool stateLoaded: false
    available: scriptFound && stateLoaded
    presets: ["Flat", "Bass", "Treble", "Vocal", "Pop", "Rock", "Jazz", "Classic"]
    function run(args) { if (available) Quickshell.execDetached([root.script, ...args]); }
    function apply(data) {
        bands = Array.from({ length: 10 }, (_, i) => Number(data["b" + (i + 1)]) || 0);
        preset = String(data.preset ?? "Custom");
        balance = Number(data.balance) || 0;
        mono = data.mono === true;
        swap = data.swap === true;
        dynamicEq = data.dyneq === true;
        dynamics = ["off", "balanced", "night"].includes(data.dynamics) ? data.dynamics : "off";
        pending = data.pending === true;
    }
    function setBand(index: int, gain: int) {
        if (index < 0 || index > 9) return;
        run(["set_band", String(index + 1), String(Math.round(Math.max(minGain, Math.min(maxGain, gain))))]);
    }
    function applyPreset(name: string) { if (presets.includes(name)) run(["preset", name]); }
    function setBalance(value: real) { run(["set_balance", String(Math.round(Math.max(-1, Math.min(1, value)) * 100) / 100)]); }
    function setFlag(name: string, on: bool) {
        const verbs = { mono: "set_mono", swap: "set_swap", dynamicEq: "set_dyneq" };
        if (verbs[name]) run([verbs[name], on ? "true" : "false"]);
    }
    function setDynamics(mode: string) { if (["off", "balanced", "night"].includes(mode)) run(["set_dynamics", mode]); }
    function resetAudio() { run(["reset_audio"]); }
    function openHost() { Quickshell.execDetached(["serpantinum", "msg", "open", "music"]); }
    FileView {
        path: root.script
        printErrors: false
        onLoaded: root.scriptFound = true
        onLoadFailed: root.scriptFound = false
    }
    // The host seeds this file itself; FART never initialises it (that may start the audio daemon).
    FileView {
        path: root.settings.runDir + "/music/eq_state.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: { try { root.apply(JSON.parse(text())); root.stateLoaded = true; } catch (_) {} }
        onLoadFailed: root.stateLoaded = false
    }
}
