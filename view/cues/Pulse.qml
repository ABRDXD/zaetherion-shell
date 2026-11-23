import QtQuick

// An impulse: rest → peak → rest, optionally repeating or a flash (docs/CUES.md §3.2).
QtObject {
    id: root
    property int attack: Motion.feedback
    property int release: attack
    property int attackEasing: Motion.standard
    property int releaseEasing: attackEasing
    property real overshoot: Motion.overshoot
    // Loop rise and fall while live (breathing indicators).
    property bool repeat: false
    // Each rise asks FlashGate first; a denied flash is dropped (§7).
    property bool flash: false
    property Item scope: null
    property string name: "pulse"
    property real value: 0
    property bool rising: false
    readonly property bool live: Motion.live(scope)
    readonly property bool running: animation.running
    property bool counted: false
    function count(on) {
        if (on === counted) return;
        counted = on;
        if (on) Motion.begin(name); else Motion.end(name);
    }
    Component.onDestruction: count(false)
    onLiveChanged: live ? startRepeat() : cancel()
    // Turned off, a loop returns to rest from where it is instead of finishing its cycle.
    onRepeatChanged: {
        if (repeat) startRepeat();
        else if (rising && animation.running) go(false);
    }
    Component.onCompleted: startRepeat()
    function trigger() {
        if (!live || (rising && animation.running)) return;
        if (flash && !FlashGate.request(name)) return;
        go(true);
    }
    function cancel() {
        animation.stop();
        rising = false;
        value = 0;
    }
    function startRepeat() {
        if (repeat && live && !animation.running) go(true);
    }
    function go(up) {
        animation.stop();
        rising = up;
        const to = up ? 1 : 0;
        const full = up ? attack : release;
        const distance = Math.min(1, Math.abs(to - value));
        if (full <= 0 || distance === 0) {
            value = to;
            if (up) go(false);
            return;
        }
        animation.from = value;
        animation.to = to;
        animation.duration = Math.max(1, Math.round(full * distance));
        animation.easing.type = up ? attackEasing : releaseEasing;
        animation.easing.overshoot = overshoot;
        animation.start();
    }
    property NumberAnimation animation: NumberAnimation {
        target: root
        property: "value"
        // Reported once per run to Motion.activeNames, including when destroyed mid-flight.
        onRunningChanged: root.count(running)
        onFinished: {
            if (root.rising) root.go(false);
            else if (root.repeat && root.live) root.go(true);
        }
    }
}
