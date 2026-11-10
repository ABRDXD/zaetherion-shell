import qs.view.contract
import qs.view.ui
import QtQuick

// Clipboard as a planet: how many entries the history holds, never what they are (privacy). The
// history is read only under the "history" lease, and the adapter empties its entries when the lease
// is released, so the face holds it until one listing arrives (at most 3 s) each time it becomes
// live, keeps the count and the image count, and lets it go. Nothing of the contents is kept here.
Face {
    id: root
    required property HostAdapter host
    readonly property var clipboard: host.clipboard
    property int count: -1
    property int images: 0
    property bool probing: false

    function take() {
        const entries = clipboard.entries;
        count = entries.length;
        images = entries.filter(e => e.isImage).length;
    }
    function probe() {
        // Someone else (the orbit's Clips system) already holds the history: its entries are current.
        if (live && clipboard.entries.length > 0) {
            take();
            probing = false;
            return;
        }
        probing = live && clipboard.available;
        if (probing)
            probeWindow.restart();
    }
    onLiveChanged: probe()
    Component.onCompleted: probe()
    // While shown it follows the history another lease keeps current; an emptied list (a lease let go)
    // keeps the last count.
    Connections {
        target: root.clipboard
        enabled: root.probing || root.live
        function onEntriesChanged() {
            if (!root.probing && root.clipboard.entries.length === 0)
                return;
            root.take();
            root.probing = false;
        }
    }
    // An empty history never changes `entries`: the window closes on its own and keeps what it saw.
    Timer {
        id: probeWindow
        interval: 3000
        onTriggered: {
            if (!root.probing)
                return;
            root.take();
            root.probing = false;
        }
    }
    HostLease { domain: root.clipboard; feature: "history"; active: root.probing }

    figure: !clipboard.available ? "–" : count < 0 ? "·" : String(count)
    brief: count < 0 ? figure : figure + " CLIPS"
    note: !clipboard.available ? "UNAVAILABLE" : count === 1 ? "ENTRY" : "ENTRIES"
    detail: count > 0 ? images + (images === 1 ? " IMAGE · " : " IMAGES · ") + (count - images) + " TEXT" : ""

    Accessible.role: Accessible.StaticText
    Accessible.name: count >= 0 ? count + " clipboard entries" : "Clipboard"
}
