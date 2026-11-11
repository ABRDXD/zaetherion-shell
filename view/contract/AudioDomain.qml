// Endpoint: { id, name, volume, muted }. Device: { id, name, isDefault }. Stream: { id, app, volume, muted }.
HostDomain {
    // Optional event-driven mic/camera snapshot for the island privacy indicator.
    property var privacy: []
    property var output: null
    property var input: null
    property var outputs: []
    property var inputs: []
    // Lease "streams": playback streams, tracked only while held.
    property var streams: []
    property EqualizerDomain equalizer: EqualizerDomain {}

    function setVolume(endpointId: string, level: real) { record("setVolume", [endpointId, level]); }
    function setMuted(endpointId: string, muted: bool) { record("setMuted", [endpointId, muted]); }
    function setDefault(kind: string, deviceId: string) { record("setDefault", [kind, deviceId]); }
}
