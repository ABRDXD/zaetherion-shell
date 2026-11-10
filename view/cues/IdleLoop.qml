import QtQuick

// An idle loop (MONTAGE.md §4.5): `phase` runs 0 → 1 every `period` ms while the loop's Idle gate is open
// (Overdrive engaged, ambient on, motion not reduced, scope visible), and holds still otherwise. Its speed
// follows Overdrive's engine (Motion.drive), so a release winds it down rather than stopping it dead; consumers
// scale their amplitude by `level` (the same engine) so everything comes to rest at 0. Every loop reads one
// shared clock (Motion.idleNow), which runs only while a loop does. Consumers bind transforms or opacity to
// `phase`, never layout. `turns` counts whole periods, for loops that drift rather than repeat.
QtObject {
    id: root
    property Item scope: null
    property string name: "loop"
    property bool enabled: true
    property int period: 4000
    property real phase: 0
    property int turns: 0
    // The engine: 1 in Overdrive, falling to 0 over the spin-down. Amplitudes multiply by it.
    readonly property real level: Motion.drive
    readonly property bool running: gate.running
    property Idle gate: Idle { scope: root.scope; name: root.name; enabled: root.enabled }
    property bool registered: false
    function register(on) {
        if (on === registered) return;
        registered = on;
        Motion.idleLoops += on ? 1 : -1;
    }
    onRunningChanged: { last = 0; register(running); }
    Component.onCompleted: register(running)
    Component.onDestruction: register(false)
    property real last: 0
    property Connections clock: Connections {
        target: Motion
        enabled: root.running
        function onIdleNowChanged() {
            const now = Motion.idleNow;
            // A first tick (or one after a long gap) does not jump.
            const dt = root.last > 0 && now - root.last < 250 ? now - root.last : 0;
            root.last = now;
            const next = root.phase + dt * Motion.drive / Math.max(1, root.period);
            if (next >= 1) root.turns += Math.floor(next);
            root.phase = next - Math.floor(next);
        }
    }
}
