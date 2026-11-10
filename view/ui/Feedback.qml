pragma Singleton
import QtQuick
import Quickshell

// UI sound moments (DAILY_DRIVER §11 Q9): controls name the moment, the view's entry routes it to
// the core (`sfx.play`), and the core's one D19 gate decides and plays the host's own sound.
// Nothing here plays audio or knows the host.
Singleton {
    // ui.click, ui.key, ui.switch, ui.error, or the orbit's orbit.out, orbit.land and orbit.hover.
    signal cue(string name)
    function play(name: string) { cue(name); }
}
