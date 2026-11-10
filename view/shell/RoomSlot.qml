import QtQuick
import qs.view.cues
import qs.view.ui

// One of Shell's two room slots. A new room incubates asynchronously in the hidden slot while
// the shown room stays visible but disabled (docs/CUES.md §4.2); Shell swaps them once it is
// ready, and a newer navigation replaces the pending one, so nothing queues. A ready room is
// staged for one frame first: laid out and synced at opacity 0, so the swap frame stays cheap.
Loader {
    id: root
    property string page: ""
    property bool shown: false
    property bool leaving: false
    property bool staging: false
    // The room entrance cue's value, applied only while shown.
    property real entrance: 1
    readonly property var role: Motion.roles.navigate
    readonly property real progress: shown ? Math.min(1, entrance) : 1
    asynchronous: true
    visible: shown || staging
    enabled: shown && !leaving
    // A room fades in and travels as the host's content swap does; a load during flight
    // retargets, so fast room keys never strobe the dip (docs/CUES.md §9, §15).
    opacity: shown ? role.fromOpacity + (1 - role.fromOpacity) * progress : 0
    transform: Translate {
        x: root.role.axis === "x" ? root.role.travel * (1 - root.progress) : 0
        y: root.role.axis === "y" ? root.role.travel * (1 - root.progress) : 0
    }
    function cancel() {
        staging = false;
        page = "";
        source = "";
    }
    onStatusChanged: if (status === Loader.Error) console.warn("FART could not load page", page)
    FText {
        anchors.centerIn: parent
        visible: root.status === Loader.Error
        text: "VIEW UNAVAILABLE"
        color: Design.muted
    }
}
