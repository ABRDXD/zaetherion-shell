import QtQuick
import Quickshell
import Quickshell.Io
import qs.view.contract

// Legacy: drives the host's own equaliser through its script; the state file is the source of truth. Only the
// parts the owner kept (Z173): the ten bands, presets and mono.
EqualizerDomain {
    id: root
    required property var settings
    readonly property string script: settings.sourceDir + "/media/equalizer.sh"
    property bool scriptFound: false
    property bool stateLoaded: false
    available: scriptFound && stateLoaded
    enabled: available
    active: available
    presets: ["Flat", "Bass", "Treble", "Vocal", "Pop", "Rock", "Jazz", "Classic"]
    function run(args) { if (available) Quickshell.execDetached([root.script, ...args]); }
    function apply(data) {
        bands = Array.from({ length: 10 }, (_, i) => Number(data["b" + (i + 1)]) || 0);
        preset = String(data.preset ?? "Custom");
        mono = data.mono === true;
    }
    function setBand(index: int, gain: int) {
        if (index < 0 || index > 9) return;
        run(["set_band", String(index + 1), String(Math.round(Math.max(minGain, Math.min(maxGain, gain))))]);
    }
    function applyPreset(name: string) { if (presets.includes(name)) run(["preset", name]); }
    function setMono(on: bool) { run(["set_mono", on ? "true" : "false"]); }
    // The host's chain has no off switch of ours: it is always in the path while its script is there.
    function setEnabled(on: bool) {}
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
