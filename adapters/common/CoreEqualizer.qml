import QtQuick
import qs.core.client
import qs.view.contract

// The equaliser the core runs (Z173): it keeps the settings and the PipeWire chain, the view reads its topic and
// asks it for changes. Works with any audio domain; the DMS session's has it.
EqualizerDomain {
    id: root
    required property CoreClient core
    readonly property var state: core.equalizerData
    available: core.connected && (state?.available ?? false)
    enabled: state?.on ?? false
    active: state?.active ?? false
    error: state?.error ?? ""
    bands: state?.bands ?? [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    preset: state?.preset ?? "Flat"
    presets: state?.presets ?? []
    mono: state?.mono ?? false

    function setEnabled(on: bool) { core.request("eq.enable", { on: on }); }
    function setBand(index: int, gain: int) {
        if (index >= 0 && index < 10) core.request("eq.band", { index: index, gain: Math.round(Math.max(minGain, Math.min(maxGain, gain))) });
    }
    function applyPreset(name: string) { if (presets.includes(name)) core.request("eq.preset", { name: name }); }
    function setMono(on: bool) { core.request("eq.mono", { on: on }); }
}
