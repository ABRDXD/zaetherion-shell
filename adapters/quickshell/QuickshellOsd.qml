// Volume and mic OSD events from Pipewire's default sink and source (Z24). Behaviour after DMS v2.1.0's
// VolumeOSD and MicVolumeOSD (MIT, see NOTICE); the decision is OsdChange.js. Lives where the island lives:
// the default nodes stay bound for as long as this object exists, which is what lets a key press show.
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs.view.contract
import "OsdChange.js" as OsdChange

OsdDomain {
    id: root
    readonly property var sinkNode: Pipewire.defaultAudioSink
    readonly property var sourceNode: Pipewire.defaultAudioSource
    // Quiet for the first 2 s, as DMS: binding the nodes reports their levels, and those are not changes.
    property bool quiet: true
    property var levels: null
    available: Pipewire.ready

    PwObjectTracker { objects: [root.sinkNode, root.sourceNode].filter(n => n) }
    Timer { interval: 2000; running: true; onTriggered: root.quiet = false }

    function sample(kind: string, node) {
        if (node?.audio && node.ready)
            offer({ kind: kind, node: node.id, level: node.audio.volume, muted: node.audio.muted });
    }
    // Any level source: { kind, node, level, muted }. A subtype adds sources (DmsOsd: brightness).
    function offer(value) {
        const result = OsdChange.next(levels, value, quiet);
        levels = result.state;
        if (result.event)
            event = result.event;
    }
    // Hold off for 2 s, e.g. after a resume or while our own UI sets a level (DMS: suppressOSDTemporarily).
    function hush() {
        quiet = true;
        hushTimer.restart();
    }
    Timer { id: hushTimer; interval: 2000; onTriggered: root.quiet = false }

    onSinkNodeChanged: sample("volume", sinkNode)
    onSourceNodeChanged: sample("mic", sourceNode)
    Connections {
        target: root.sinkNode?.audio ?? null
        function onVolumeChanged() { root.sample("volume", root.sinkNode); }
        function onMutedChanged() { root.sample("volume", root.sinkNode); }
    }
    Connections {
        target: root.sourceNode?.audio ?? null
        function onVolumeChanged() { root.sample("mic", root.sourceNode); }
        function onMutedChanged() { root.sample("mic", root.sourceNode); }
    }
    Connections {
        target: root.sinkNode
        function onReadyChanged() { root.sample("volume", root.sinkNode); }
    }
    Connections {
        target: root.sourceNode
        function onReadyChanged() { root.sample("mic", root.sourceNode); }
    }
}
