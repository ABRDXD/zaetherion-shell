// Cue names are FART's (timer.done, pomodoro.phase, nav.open, ignite); the adapter maps them to files.
// DND and session gating is FART policy, applied before play().
HostDomain {
    property bool muted: false
    property real volume: 1

    function play(cue: string, gain: real) { record("play", [cue, gain]); }
}
