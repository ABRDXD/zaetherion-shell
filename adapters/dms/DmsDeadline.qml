import QtQuick

// One timer for the earliest of a domain's deadlines (attempts, prompts). `at` is a Date.now() time, or -1 for none.
// `due()` fires once at that time; the domain ticks its states, which moves `at` and re-arms this.
Item {
    id: root
    property real at: -1
    signal due()
    onAtChanged: arm()
    function arm() {
        if (root.at < 0) { timer.stop(); return; }
        timer.interval = Math.max(1, root.at - Date.now());
        timer.restart();
    }
    Timer { id: timer; repeat: false; onTriggered: { root.due(); root.arm(); } }
}
