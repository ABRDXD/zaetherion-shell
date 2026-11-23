import qs.core.client
import QtQuick

// The view's handle on the core's Overdrive lease (docs/CORE.md §6, docs/OVERDRIVE.md §1): what is requested,
// what is in effect and why, and the requests the panel can make. Plain data from the `overdrive` and
// `ignite` topics; the core owns every timing (the hold, a timed lease's end) and every transition.
QtObject {
    id: root
    required property CoreClient core
    readonly property var data: core.overdriveData
    // off | timed | panel | sticky
    readonly property string mode: data?.requested?.mode ?? "off"
    // off | active | suspended
    readonly property string effective: data?.effective ?? "off"
    readonly property bool requested: mode !== "off"
    readonly property bool active: effective === "active"
    readonly property bool suspended: effective === "suspended"
    // The guards that are on now, suspending the lease (dgpu, fullscreen, battery, session).
    readonly property var reasons: data?.reasons ?? []
    // Each guard's availability on this machine: { dgpu: "available" | "unavailable", … }.
    readonly property var guards: data?.guards ?? ({})
    // A timed lease's end, epoch ms; null otherwise.
    readonly property var until: data?.requested?.until ?? null
    readonly property var ignite: core.igniteData
    readonly property bool holding: !!ignite?.holding
    readonly property bool fired: !!ignite?.fired
    readonly property double holdSince: ignite?.since ?? 0
    // The last thing the machine was heard doing (core/quiet.py), so a faint sound can be looked up: { cue, at }.
    property var heard: null
    readonly property var heardNames: ({ "quiet.thrash": "memory under pressure", "quiet.burst": "network burst", "quiet.device": "USB device changed" })
    property Connections heardCues: Connections {
        target: root.core
        function onCue(data) { if (data.audible && root.heardNames[data.cue]) root.heard = { cue: data.cue, at: data.at }; }
    }
    readonly property var guardNames: ({ dgpu: "dGPU awake", fullscreen: "fullscreen window", battery: "on battery", session: "session" })
    function reason() {
        return reasons.map(r => guardNames[r] ?? r).join(" · ");
    }
    function request(mode, seconds) {
        core.request("overdrive.request", seconds ? { mode: mode, seconds: seconds } : { mode: mode });
    }
    function release() {
        core.request("overdrive.release", {});
    }
    // The ignite plate: the press and the release; the core times the 600 ms hold (D16) and fires or cuts.
    function holdDown() {
        core.request("key.down", { panel: true });
    }
    function holdUp() {
        core.request("key.up", {});
    }
}
