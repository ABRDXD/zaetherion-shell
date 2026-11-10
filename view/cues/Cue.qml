import QtQuick

// A state cue: `value` follows `on` between 0 and 1 (docs/CUES.md §3.1).
// A new target retargets from the current value over a duration proportional to the
// distance left; nothing is queued, and an invisible cue settles at once.
QtObject {
    id: root
    property bool on: false
    property int enter: Motion.navigate
    property int exit: enter
    property int easing: Motion.standard
    property int exitEasing: easing
    property real overshoot: Motion.overshoot
    property Item scope: null
    property string name: "cue"
    property real value: 0
    readonly property real target: on ? 1 : 0
    readonly property bool live: Motion.live(scope)
    readonly property bool running: animation.running
    property bool counted: false
    function count(on) {
        if (on === counted) return;
        counted = on;
        if (on) Motion.begin(name); else Motion.end(name);
    }
    Component.onDestruction: count(false)
    // Visual follow-up only (§4.2): never page changes, focus, writes or host calls.
    signal settled
    // A cue starts at its target: bindings settling during creation never animate.
    property bool ready: false
    onTargetChanged: if (ready) retarget()
    onLiveChanged: if (!live) settle()
    Component.onCompleted: {
        value = target;
        ready = true;
    }
    function retarget() {
        animation.stop();
        const rising = target > value;
        const full = rising ? enter : exit;
        const distance = Math.min(1, Math.abs(target - value));
        if (!live || distance === 0 || full <= 0) {
            settle();
            return;
        }
        animation.from = value;
        animation.to = target;
        animation.duration = Math.max(1, Math.round(full * distance));
        animation.easing.type = rising ? easing : exitEasing;
        animation.easing.overshoot = overshoot;
        animation.start();
    }
    // Jump to the target now.
    function settle() {
        const moved = animation.running || value !== target;
        animation.stop();
        value = target;
        if (moved) settled();
    }
    // New content entering: start again from rest, unless the cue is already in flight,
    // so repeated entrances retarget instead of strobing (§9, Shell entrance).
    function replay() {
        if (animation.running || !on) return;
        if (!live) { settle(); return; }
        value = 0;
        retarget();
    }
    property NumberAnimation animation: NumberAnimation {
        target: root
        property: "value"
        // Reported once per run to Motion.activeNames, including when destroyed mid-flight.
        onRunningChanged: root.count(running)
        onFinished: root.settled()
    }
}
