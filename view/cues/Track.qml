import QtQuick

// One eased window [start, end] of a Timeline's linear driver.
QtObject {
    id: root
    property QtObject timeline: null
    property real start: 0
    property real end: 1
    property int easing: Motion.standard
    property real overshoot: Motion.overshoot
    readonly property real progress: timeline ? Math.max(0, Math.min(1, (timeline.value - start) / Math.max(0.0001, end - start))) : 0
    readonly property real value: progress <= 0 ? 0 : progress >= 1 ? 1 : curve.easing.valueForProgress(progress)
    // Never started: it only evaluates the easing token.
    property PropertyAnimation curve: PropertyAnimation {
        easing.type: root.easing
        easing.overshoot: root.overshoot
    }
}
