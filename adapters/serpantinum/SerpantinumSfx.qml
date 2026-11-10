import QtQuick
import Quickshell
import qs.view.contract

// Same route as the host's Sounds.qml: pw-play with an event role, scaled by the host's sfx volume.
SfxDomain {
    id: root
    required property var settings
    readonly property string soundDir: "/usr/share/sounds/freedesktop/stereo/"
    readonly property var cues: ({ "timer.done": "alarm-clock-elapsed.oga", "pomodoro.phase": "alarm-clock-elapsed.oga" })
    available: true
    muted: settings.values.general?.muteSfx === true
    volume: Math.max(0, Math.min(1, Number(settings.values.general?.sfxVolume ?? 100) / 100))

    function play(cue: string, gain: real) {
        if (muted || volume <= 0 || !cues[cue]) return;
        const level = Math.max(0, Math.min(2, (gain ?? 1) * volume));
        Quickshell.execDetached(["pw-play", "-P", JSON.stringify({ "application.id": "fart-sfx", "application.name": "FART", "media.role": "event" }),
            "--volume=" + level, soundDir + cues[cue]]);
    }
}
