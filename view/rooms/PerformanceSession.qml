import QtQuick
import Quickshell
import qs.view.contract
import qs.view.shell
import qs.view.ui

// One owner for the Performance room's readings, leases and weather, shared by both presentations (Angular's halo
// and Fluid's star), so a presentation change keeps the samples and holds the leases exactly once.
Item {
    id: root
    required property HostAdapter host
    required property ShellContext shell
    property bool shown: false
    readonly property bool active: shown && root.shell.panelOpen
    readonly property var system: host.system
    readonly property var cpu: system.cpu
    readonly property var memory: system.memory
    readonly property var disk: system.disk
    readonly property var sensor: system.gpu
    // How full memory is: how long the palimpsest's impressions linger (Overdrive, atlas #71).
    readonly property real memoryPressure: memory.available && memory.total > 0 ? memory.used / memory.total : 0
    readonly property real diskUsed: disk.total > 0 ? disk.used / disk.total : 0
    readonly property bool diskCritical: disk.available && diskUsed >= 0.95
    readonly property bool diskWarning: disk.available && diskUsed >= 0.85
    readonly property bool temperatureAvailable: cpu.temperature !== null && cpu.temperature !== undefined
    readonly property bool gpuTemperature: sensor.temperature !== null && sensor.temperature !== undefined
    function gigabytes(kb) { return (kb / (1024 * 1024)).toFixed(1) + " GB"; }
    function percent(available, value) { return available ? Math.round(value * 100) + "%" : "—"; }
    // One entry per reading, for the halo and the record. `history` is empty where there is none.
    readonly property var readings: [
        {
            key: "cpu", label: "CPU", name: "Processor",
            available: cpu.available, value: cpu.usage, text: percent(cpu.available, cpu.usage),
            hot: temperatureAvailable && cpu.temperature >= 90, history: cpu.history,
            unavailable: "Sampling…",
            line: temperatureAvailable ? cpu.temperature.toFixed(0) + "°C" : system.cpuModel,
            facts: [["Model", system.cpuModel || "—"], ["Temperature", temperatureAvailable ? cpu.temperature.toFixed(0) + "°C" : "—"],
                    ["Cadence", (system.sampleInterval / 1000).toFixed(1) + " s"]]
        },
        {
            key: "memory", label: "MEM", name: "Memory",
            available: memory.available && memory.total > 0, value: memory.total > 0 ? memory.used / memory.total : 0,
            text: percent(memory.available && memory.total > 0, memory.total > 0 ? memory.used / memory.total : 0),
            hot: false, history: memory.history, unavailable: "Sampling…",
            line: gigabytes(memory.used) + " of " + gigabytes(memory.total),
            facts: [["Used", gigabytes(memory.used)], ["Total", gigabytes(memory.total)], ["Free", gigabytes(Math.max(0, memory.total - memory.used))]]
        },
        {
            key: "gpu", label: "GPU", name: "Graphics",
            available: sensor.available, value: sensor.usage, text: percent(sensor.available, sensor.usage),
            hot: gpuTemperature && sensor.temperature >= 90, history: sensor.history,
            unavailable: sensor.error || "Unavailable",
            line: sensor.available ? (gpuTemperature ? sensor.temperature.toFixed(0) + "°C" : sensor.source) : sensor.error,
            facts: [["Source", sensor.source || "—"], ["Temperature", gpuTemperature ? sensor.temperature.toFixed(0) + "°C" : "—"],
                    ["VRAM", sensor.vramTotal > 0 && sensor.vramUsed !== null ? (sensor.vramUsed / 1048576).toFixed(0) + " of " + (sensor.vramTotal / 1048576).toFixed(0) + " MiB" : "—"]]
        },
        {
            key: "disk", label: "DISK", name: "Root volume",
            available: disk.available, value: diskUsed, text: percent(disk.available, diskUsed),
            hot: diskCritical, warm: diskWarning, history: [], unavailable: "Storage pending",
            line: disk.available ? gigabytes(disk.free) + " free" : "Storage pending",
            facts: [["Free", gigabytes(disk.free)], ["Used", gigabytes(disk.used)], ["Total", gigabytes(disk.total)]]
        },
        {
            key: "swap", label: "SWAP", name: "Swap",
            available: memory.available && memory.swapTotal > 0, value: memory.swapTotal > 0 ? memory.swapUsed / memory.swapTotal : 0,
            text: memory.swapTotal > 0 ? percent(memory.available, memory.swapUsed / memory.swapTotal) : "—",
            hot: false, history: [], unavailable: memory.swapTotal > 0 ? "Sampling…" : "No swap",
            line: gigabytes(memory.swapUsed) + " of " + gigabytes(memory.swapTotal),
            facts: [["Used", gigabytes(memory.swapUsed)], ["Total", gigabytes(memory.swapTotal)]]
        }
    ]

    // The machine's weather (core/weather.py): asked once each time the room is shown, never polled.
    property var weather: null
    onActiveChanged: if (active) shell.core?.request("weather.now", {}, (ok, result) => { if (ok && result && root) root.weather = result; })
    Component.onCompleted: if (active) shell.core?.request("weather.now", {}, (ok, result) => { if (ok && result && root) root.weather = result; })
    // The barograph: each report's pressure, newest at the right, 960–1040 hPa over its height.
    readonly property var barograph: {
        const marks = (weather?.barograph ?? []).filter(b => Number.isFinite(b.hpa));
        return marks.map((b, i) => Qt.point(marks.length > 1 ? i * 64 / (marks.length - 1) : 0, 14 - Math.max(0, Math.min(14, (b.hpa - 960) / 80 * 14))));
    }
    readonly property string weatherDetail: {
        const w = weather?.latest;
        if (!w)
            return "";
        const from = new Date((w.at - w.span) * 1000), hours = Math.floor(w.span / 3600), minutes = Math.round(w.span % 3600 / 60);
        return "SINCE " + String(from.getHours()).padStart(2, "0") + ":" + String(from.getMinutes()).padStart(2, "0") + " · "
            + (hours > 0 ? hours + " H " : "") + minutes + " MIN\n" + w.detail.toUpperCase();
    }
    HostLease { domain: root.system; feature: "resources"; active: root.active }
    HostLease { domain: root.system; feature: "gpu"; active: root.active }
}
