import QtQuick
import qs.view.cues

// Z161: a critical event flashes red once. `value` rises to 1 and falls back to 0 after each `fire()`.
// With motion off (`still`) it is a plain hold of `holdMs` instead of a fade. The flash shares the flash limit
// (D17, FlashGate): a burst of critical events flashes at most three times a second, the rest are dropped; the
// critical notice itself stays on the island, so nothing is lost. The still hold is not a flash.
Item {
    id: root
    property bool still: false
    property int holdMs: 600
    readonly property real value: cue.value
    function fire(): void {
        if (root.still || FlashGate.request(cue.name)) cue.on = true;
    }

    Cue {
        id: cue
        scope: root
        name: "critical.flash"
        enter: root.still ? 0 : 180
        exit: root.still ? 0 : 520
        onSettled: if (on) hold.start()
    }
    Timer {
        id: hold
        interval: root.still ? root.holdMs : 60
        onTriggered: cue.on = false
    }
}
