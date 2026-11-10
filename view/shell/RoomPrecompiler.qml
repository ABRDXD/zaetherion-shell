import QtQuick

// Quickshell's qs:@/ URLs bypass Qt's QML disk cache, so every view process compiles each room on
// its first visit (nav-timing fix 3). Once the panel has settled, this compiles the rooms one per
// tick on the type loader's thread, without instantiating them, and holds the components so the
// compiled units stay cached. It stops when every room is compiled, so it has no idle cost.
QtObject {
    id: root
    property var urls: []
    // True while the panel is open and nothing moves.
    property bool idle: false
    property int next: 0
    readonly property bool done: next >= urls.length
    property var components: []
    property Timer timer: Timer {
        interval: 100
        repeat: true
        running: root.idle && !root.done
        onTriggered: {
            root.components.push(Qt.createComponent(root.urls[root.next], Component.Asynchronous));
            root.next++;
        }
    }
}
