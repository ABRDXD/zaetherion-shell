import QtQml

// A single sampled clock drives live playback, stills, skip and reduced motion.
// Each pair of times marks contact or release for one physical piece.
QtObject {
    id: cue
    required property int elapsed

    function smooth(start, end) {
        const p = Math.max(0, Math.min(1, (elapsed - start) / (end - start)));
        return p * p * (3 - 2 * p);
    }
    readonly property real unlock: smooth(925, 988)
    readonly property real throwTab: smooth(976, 1195)
    readonly property real climb: smooth(1110, 1378)
    readonly property real turnover: smooth(1040, 1250)
    readonly property real compression: Math.sin(Math.PI * turnover)
    readonly property real contact: smooth(1340, 1390) - smooth(1390, 1455)
    readonly property real cut: smooth(990, 1260)
    readonly property real lift: smooth(958, 1035)
    readonly property real strike: smooth(1010, 1325)
    readonly property real stamp: smooth(1280, 1360) - smooth(1360, 1435)
    readonly property real leftPull: smooth(1080, 1380)
    readonly property real rightPull: smooth(1160, 1450)
}
