// Machine identity and telemetry. Sizes in KiB, ratios 0..1.
HostDomain {
    property string user: ""
    property string hostname: ""
    property string cpuModel: ""
    property real uptime: 0
    // Lease "resources".
    property int sampleInterval: 3000
    property var cpu: ({ available: false, usage: 0, history: [], temperature: null })
    property var memory: ({ available: false, total: 0, used: 0, history: [], swapTotal: 0, swapUsed: 0 })
    property var disk: ({ available: false, total: 0, used: 0, free: 0 })
    // Lease "gpu": { available, failed, usage, temperature, vramUsed, vramTotal, source, error, history }.
    property var gpu: ({ available: false, failed: false, usage: 0, temperature: null, vramUsed: null, vramTotal: null, source: "", error: "Sampling GPU…", history: [] })
}
