import QtQuick

// One linear driver for several eased Tracks (docs/CUES.md §3.3). Reversing retraces
// every track, so a stagger leaves in the opposite order it arrived.
Cue {
    id: root
    default property list<Track> tracks
    easing: Motion.linear
    exitEasing: Motion.linear
    name: "timeline"
    Component.onCompleted: {
        for (const track of tracks)
            track.timeline = root;
    }
}
