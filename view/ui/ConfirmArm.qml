import QtQuick

// Ask twice (behaviour only): the first press arms, a second press within `window` ms confirms; otherwise it disarms
// by itself. FConfirmButton and Settings' text actions both use it, so the rule lives in one place.
QtObject {
    id: root
    property int window: 3000
    property bool armed: false
    signal confirmed()
    function press() {
        if (armed) { armed = false; disarm.stop(); confirmed(); }
        else { armed = true; disarm.restart(); }
    }
    function cancel() { armed = false; disarm.stop(); }
    property Timer disarm: Timer { interval: root.window; onTriggered: root.armed = false }
}
