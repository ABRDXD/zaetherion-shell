import qs.view.cues
import qs.view.ui
import QtQuick

// The discovery whisper (M15, core/discovery.py): when a fragment is found, one faint neutral line under the current
// room for about a second, then gone; the fragment itself goes to the archive. A find made while the panel was
// closed is whispered the next time it opens. Under reduced motion it appears and goes without a fade.
Item {
    id: root
    // core.discoveryData.whisper: { id, text } or null
    property var pending: null
    property bool open: false
    signal seen(string id)
    property string text: ""
    implicitHeight: line.implicitHeight
    implicitWidth: line.implicitWidth
    readonly property bool showing: hold.running
    function consider() {
        if (!open || !pending || hold.running)
            return;
        text = pending.text;
        hold.restart();
        fade.trigger();
        seen(pending.id);
    }
    onPendingChanged: consider()
    onOpenChanged: if (open) settle.restart()
    // Once the panel has settled, not during its entrance.
    Timer { id: settle; interval: 600; onTriggered: root.consider() }
    Timer { id: hold; interval: 1300; onTriggered: { root.text = ""; root.consider(); } }
    Pulse {
        id: fade
        name: "discovery.whisper"
        scope: root
        attack: Motion.scaled(220)
        release: Motion.scaled(1000)
    }
    FText {
        id: line
        text: root.text
        visible: hold.running
        aside: true
        color: Design.faint
        opacity: fade.live ? fade.value : 0.7
    }
}
