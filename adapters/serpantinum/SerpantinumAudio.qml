import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs.view.contract

AudioDomain {
    id: root
    readonly property var nodes: Pipewire.nodes.values
    readonly property var sinkNode: Pipewire.defaultAudioSink
    readonly property var sourceNode: Pipewire.defaultAudioSource
    readonly property var deviceNodes: nodes.filter(n => n.audio && !n.isStream)
    readonly property var streamNodes: nodes.filter(n => n.audio && n.isStream && n.isSink)
    readonly property bool mixing: holds("mixer")
    function name(n) { return n.nickname || n.description || n.name; }
    // Null until the tracker has bound the node, so a waiting host call never reads or sets a stale level.
    function endpoint(n) {
        return n?.audio && n.ready ? { id: String(n.id), name: name(n), volume: n.audio.volume, muted: n.audio.muted } : null;
    }
    function node(id) { return nodes.find(n => String(n.id) === id) ?? null; }
    available: Pipewire.ready
    // Levels are valid only while a "mixer" lease binds the nodes.
    output: mixing ? endpoint(sinkNode) : null
    input: mixing ? endpoint(sourceNode) : null
    outputs: deviceNodes.filter(n => n.isSink).map(n => ({ id: String(n.id), name: name(n), isDefault: n === sinkNode }))
    inputs: deviceNodes.filter(n => !n.isSink).map(n => ({ id: String(n.id), name: name(n), isDefault: n === sourceNode }))
    streams: mixing ? streamNodes.map(n => ({ id: String(n.id), app: n.properties["application.name"] || n.description || n.name,
        volume: n.audio?.volume ?? 0, muted: n.audio?.muted ?? false })) : []
    PwObjectTracker { objects: root.mixing ? [root.sinkNode, root.sourceNode, ...root.streamNodes].filter(n => n) : [] }

    function setVolume(endpointId: string, level: real) {
        const n = node(endpointId);
        if (n?.audio) n.audio.volume = Math.max(0, Math.min(1, level));
    }
    function setMuted(endpointId: string, muted: bool) {
        const n = node(endpointId);
        if (n?.audio) n.audio.muted = muted;
    }
    function setDefault(kind: string, deviceId: string) {
        const n = node(deviceId);
        if (!n) return;
        if (kind === "output") Pipewire.preferredDefaultAudioSink = n;
        else if (kind === "input") Pipewire.preferredDefaultAudioSource = n;
    }
}
