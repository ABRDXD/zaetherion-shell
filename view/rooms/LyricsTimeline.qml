import QtQuick

// Which lyric line is current, from a sampled position. Wakes only at line boundaries while playing.
QtObject {
    id: root
    property var lines: []
    property real position: 0
    property real positionStamp: 0
    property bool playing: false
    property bool active: false
    readonly property real lead: 0.15
    property int index: -1
    readonly property string currentText: index >= 0 && index < lines.length ? (lines[index].text || "♪") : ""
    function now() { return playing ? position + (Date.now() - positionStamp) / 1000 : position; }
    function indexAt(pos) {
        let low = 0, high = lines.length - 1, result = -1;
        while (low <= high) {
            const mid = (low + high) >> 1;
            if (lines[mid].time <= pos) { result = mid; low = mid + 1; } else high = mid - 1;
        }
        return result;
    }
    function update() {
        boundary.stop();
        if (!active || lines.length === 0) { index = -1; return; }
        const pos = now() + lead;
        index = indexAt(pos);
        const next = lines[index + 1];
        if (!playing || !next) return;
        boundary.interval = Math.max(1, Math.ceil((next.time - pos) * 1000));
        boundary.start();
    }
    onLinesChanged: update()
    onPositionStampChanged: update()
    onPlayingChanged: update()
    onActiveChanged: update()
    property Timer boundary: Timer { onTriggered: root.update() }
}
