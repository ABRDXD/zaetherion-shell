import QtQuick
import qs.view.cues

// The panel opens like a host popup (docs/CUES.md §15): one Timeline drives the body, then
// the header and index, then the room, each in its own eased window of the host profile.
// Closing retraces it over `fold`, so the room leaves first and the Out curves accelerate.
Timeline {
    id: root
    readonly property var spec: Motion.roles.unfold
    readonly property Track body: Track { timeline: root; start: root.spec.body.start; end: root.spec.body.end; easing: root.spec.body.easing; overshoot: root.spec.body.overshoot ?? Motion.overshoot }
    readonly property Track header: Track { timeline: root; start: root.spec.header.start; end: root.spec.header.end; easing: root.spec.header.easing; overshoot: root.spec.header.overshoot ?? Motion.overshoot }
    readonly property Track room: Track { timeline: root; start: root.spec.room.start; end: root.spec.room.end; easing: root.spec.room.easing; overshoot: root.spec.room.overshoot ?? Motion.overshoot }
    // What each part's value moves (consumers clamp opacity; the header may overshoot).
    readonly property real bodyScale: spec.body.scale + (1 - spec.body.scale) * body.value
    readonly property real bodyRise: spec.body.rise * (1 - body.value)
    readonly property real headerRise: spec.header.rise * (1 - header.value)
    readonly property real roomRise: spec.room.rise * (1 - room.value)
    name: "overlay.unfold"
    enter: Motion.unfold
    exit: Motion.fold
}
