pragma Singleton
import QtQuick
import Quickshell

// Motion tokens, liveness and the activity count for every cue (docs/CUES.md §5, §8, §15).
// Each role has a duration, an easing and an overshoot. The host's profile (the adapter's
// `motion` domain, bound by Overlay) overrides FART's defaults role by role.
Singleton {
    id: root
    // Bound by Overlay from the FART preference; cues never read view state themselves.
    property bool reduced: false
    // Idle loops (Idle.qml) run only while this is on; Shell binds it to the ambient preference.
    property bool ambient: true
    // Overdrive (M8+): the mode where everything animates. Off, nothing moves at rest: no idle loops, no
    // breathing dot, no playing-state motion. The user cut idle motion on 8 November 2026 (its cost:
    // docs/ORBIT.md §6); it comes back only here. Overlay binds it to the core's lease (effective "active"),
    // so a suspended or released lease is Silent.
    property bool overdrive: false
    // The engine (docs/OVERDRIVE.md §3): 0 in Silent, 1 in Overdrive. It spins up on ignition and winds down on
    // release, so Overdrive's motion slows to rest instead of snapping; every loop's speed and every effect's
    // strength scale with it. Strata and idle loops exist while it is engaged; at 0 they are destroyed.
    // Reduced motion snaps it to 0 and keeps it there.
    property real drive: 0
    readonly property bool driving: overdrive && !reduced
    readonly property bool engaged: driving || drive > 0
    readonly property int spinUp: scaled(900)
    readonly property int spinDown: scaled(1600)
    // Whether any FART surface is on screen (Overlay binds the panel's). Unseen, the engine snaps instead of
    // spinning, since a finite cue never runs while nobody can see it (CUES rule 3).
    property bool seen: true
    onDrivingChanged: root.retargetDrive()
    onSeenChanged: if (!seen) root.settleDrive()
    function retargetDrive() {
        const to = root.driving ? 1 : 0;
        driveRun.stop();
        const ms = Math.round((root.driving ? root.spinUp : root.spinDown) * Math.abs(to - root.drive));
        if (ms <= 0 || root.reduced || !root.seen) {
            root.drive = to;
            return;
        }
        driveRun.from = root.drive;
        driveRun.to = to;
        driveRun.duration = ms;
        driveRun.easing.type = root.driving ? Easing.OutCubic : Easing.InOutSine;
        driveRun.start();
    }
    // Jump to the target now (tests; reduced motion does it by itself).
    function settleDrive() {
        driveRun.stop();
        root.drive = root.driving ? 1 : 0;
    }
    property NumberAnimation driveRun: NumberAnimation {
        target: root
        property: "drive"
        onRunningChanged: running ? root.begin("overdrive.drive") : root.end("overdrive.drive")
    }
    // The idle clock, shared by every running IdleLoop and stopped when none runs. In Overdrive it ticks every
    // frame (idleInterval 0; FART goes all the way, docs/OVERDRIVE.md records the cost); a fixed interval
    // (FART_IDLE_MS in the measurement harness) runs a timer instead, for a cost-versus-rate sweep.
    property int idleLoops: 0
    property real idleNow: 0
    property int idleInterval: 0
    property Timer idleClock: Timer {
        interval: Math.max(1, root.idleInterval)
        repeat: true
        running: root.idleLoops > 0 && root.idleInterval > 0
        onTriggered: root.idleNow = Date.now()
    }
    property FrameAnimation idleFrames: FrameAnimation {
        running: root.idleLoops > 0 && root.idleInterval <= 0
        onTriggered: root.idleNow = Date.now()
    }
    // The fixture harness slows every token so frame jitter stays small next to a cue (§10).
    property real timeScale: 1
    // The host's roles, as plain data. A missing role or field keeps the default.
    property var profile: ({})
    // FART's own values, which the fixture uses. Durations in ms; distances in px.
    readonly property var defaults: ({
        // Button fill, creature eye.
        feedback: { duration: 100, easing: Easing.Linear },
        // Room entrance: content travels `travel` along `axis` and fades in from `fromOpacity`.
        navigate: { duration: 140, easing: Easing.OutCubic, travel: 6, axis: "x", fromOpacity: 0.7 },
        // Calendar month.
        swap: { duration: 180, easing: Easing.OutCubic },
        // The orbit camera (docs/ORBIT.md §4): a room switch zooms out to the orbit, crosses it and dives
        // into the next room; opening and closing the orbit is one zoom.
        transfer: { duration: 1000, easing: Easing.Linear },
        zoom: { duration: 440, easing: Easing.Linear },
        // Portrait parallax, calendar day radius.
        settle: { duration: 180, easing: Easing.OutCubic },
        // Calendar day colour.
        tint: { duration: 140, easing: Easing.Linear },
        // Calendar day scale.
        emphasis: { duration: 220, easing: Easing.OutBack, overshoot: 0.55 },
        // Panel open: one linear driver over `duration`, with an eased window per part.
        unfold: { duration: 240,
            body: { start: 0, end: 1, easing: Easing.OutCubic, rise: 0, scale: 1 },
            header: { start: 0, end: 1, easing: Easing.OutCubic, rise: 0 },
            room: { start: 0, end: 1, easing: Easing.OutCubic, rise: 0 } },
        // Panel close: the unfold retraced over `duration`.
        fold: { duration: 140 }
    })
    readonly property var roles: {
        const result = {};
        for (const name in defaults)
            result[name] = Object.assign({ overshoot: 1.70158 }, defaults[name], profile?.[name] ?? {});
        return result;
    }
    function scaled(ms) { return root.reduced ? 0 : Math.round(ms * root.timeScale); }
    // Effective durations: 0 when reduced.
    readonly property int feedback: scaled(roles.feedback.duration)
    readonly property int navigate: scaled(roles.navigate.duration)
    readonly property int swap: scaled(roles.swap.duration)
    readonly property int transfer: scaled(roles.transfer.duration)
    readonly property int zoom: scaled(roles.zoom.duration)
    readonly property int settle: scaled(roles.settle.duration)
    readonly property int tint: scaled(roles.tint.duration)
    readonly property int emphasis: scaled(roles.emphasis.duration)
    readonly property int unfold: scaled(roles.unfold.duration)
    readonly property int fold: scaled(roles.fold.duration)
    // How long a transient label (the track-change satellite) stays readable. Not motion, so reduced
    // motion keeps it; the harness's timeScale still shortens it.
    readonly property int dwell: Math.round(3000 * root.timeScale)
    // FART's own motion, which no host profile changes (§15.2: no host equivalent).
    readonly property int breath: scaled(550)
    readonly property int pressIn: scaled(100)
    readonly property int pressOut: scaled(140)
    readonly property int standard: Easing.OutCubic
    readonly property int expressive: Easing.OutBack
    readonly property real overshoot: 0.55
    readonly property int linear: Easing.Linear
    readonly property int nudge: 6
    // An item is live when motion is on and it can be seen; null means "no scope".
    function live(item) {
        return !root.reduced && (!item || (item.visible && (item.QsWindow.window?.visible ?? true)));
    }
    // Names of the animations running now. Settled, everything is empty (rule 3).
    property var activeNames: []
    readonly property int active: activeNames.length
    function begin(name) { activeNames = [...activeNames, name]; }
    function end(name) {
        const index = activeNames.indexOf(name);
        if (index < 0) return;
        const names = activeNames.slice();
        names.splice(index, 1);
        activeNames = names;
    }
}
