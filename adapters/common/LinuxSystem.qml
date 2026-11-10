import QtQuick
import Quickshell
import Quickshell.Io
import qs.view.contract
import "ResourceMath.js" as ResourceMath

// Machine identity from procfs; telemetry only while "resources" or "gpu" is leased.
SystemDomain {
    id: root
    readonly property bool sampling: holds("resources")
    readonly property bool gpuSampling: holds("gpu")
    readonly property int historyLength: 60
    property var previousCpu: undefined
    property string thermalPath: ""
    property int diskTick: 0
    available: true
    user: Quickshell.env("USER") || "user"

    function pushHistory(history, value) { return [...history, value].slice(-historyLength); }
    function setTemperature(value) {
        if (Number.isFinite(value) && value > 0) cpu = Object.assign({}, cpu, { temperature: value > 200 ? Math.round(value / 100) / 10 : value });
    }
    onSamplingChanged: if (!sampling) {
        previousCpu = undefined;
        cpu = Object.assign({}, cpu, { available: false, history: [] });
        memory = Object.assign({}, memory, { history: [] });
    }
    onGpuSamplingChanged: if (!gpuSampling) gpuProbe.running = false

    FileView { path: "/etc/hostname"; printErrors: false; onLoaded: root.hostname = text().trim() }
    FileView {
        path: "/proc/cpuinfo"
        printErrors: false
        onLoaded: {
            const model = (text().match(/^model name\s*:\s*(.+)$/m)?.[1] ?? "").trim();
            root.cpuModel = model.replace("Intel(R)", "Intel®").replace("Core(TM)", "Core™").replace("CPU ", "").replace(/\s+/g, " ").replace(/ @ */, " @");
        }
    }
    SystemClock { id: minute; precision: SystemClock.Minutes; onDateChanged: uptimeFile.reload() }
    FileView { id: uptimeFile; path: "/proc/uptime"; printErrors: false; onLoaded: root.uptime = parseFloat(text()) || 0 }

    Timer {
        interval: root.sampleInterval
        triggeredOnStart: true
        running: root.sampling
        repeat: true
        onTriggered: {
            meminfo.reload();
            stat.reload();
            if (root.thermalPath) thermal.reload();
            else if (!thermalSearch.running && !sensors.running) sensors.running = true;
            if (root.diskTick++ % 10 === 0 && !diskProbe.running) diskProbe.running = true;
        }
    }
    // reload() is asynchronous: consume completed reads, never the previous cached text.
    FileView {
        id: meminfo
        path: "/proc/meminfo"
        onLoaded: {
            if (!root.sampling) return;
            const data = text();
            const field = name => Number(data.match(new RegExp(name + ": *(\\d+)"))?.[1]);
            const total = field("MemTotal"), free = field("MemAvailable");
            if (!(total > 0) || !Number.isFinite(free)) { root.memory = Object.assign({}, root.memory, { available: false }); return; }
            root.memory = { available: true, total: total, used: total - free, history: root.pushHistory(root.memory.history, (total - free) / total),
                swapTotal: field("SwapTotal") || 0, swapUsed: (field("SwapTotal") || 0) - (field("SwapFree") || 0) };
        }
        onLoadFailed: root.memory = Object.assign({}, root.memory, { available: false })
    }
    FileView {
        id: stat
        path: "/proc/stat"
        onLoaded: {
            if (!root.sampling) return;
            const sample = ResourceMath.cpuSample(text());
            const usage = ResourceMath.cpuDelta(root.previousCpu, sample);
            root.previousCpu = sample;
            if (usage === null) { root.cpu = Object.assign({}, root.cpu, { available: false }); return; }
            root.cpu = Object.assign({}, root.cpu, { available: true, usage: usage, history: root.pushHistory(root.cpu.history, usage) });
        }
        onLoadFailed: { root.previousCpu = undefined; root.cpu = Object.assign({}, root.cpu, { available: false }); }
    }
    Process {
        id: thermalSearch
        running: true
        command: ["sh", "-c", "for h in /sys/class/hwmon/hwmon*; do [ -d \"$h\" ] || continue; for l in \"$h\"/temp*_label; do [ -f \"$l\" ] || continue; if grep -qE 'Package id 0|Tctl|Tdie' \"$l\" 2>/dev/null; then inp=\"${l%_label}_input\"; [ -f \"$inp\" ] && echo \"$inp\" && exit 0; fi; done; done; for z in /sys/class/thermal/thermal_zone*; do [ -d \"$z\" ] || continue; type=$(cat \"$z/type\" 2>/dev/null); case \"$type\" in x86_pkg_temp|cpu*|TCPU) [ -f \"$z/temp\" ] && echo \"$z/temp\" && exit 0;; esac; done; for t in /sys/class/hwmon/hwmon*/temp1_input /sys/class/thermal/thermal_zone0/temp; do [ -f \"$t\" ] && echo \"$t\" && exit 0; done"]
        stdout: StdioCollector { onStreamFinished: root.thermalPath = text.trim() }
    }
    FileView { id: thermal; path: root.thermalPath; printErrors: false; onLoaded: root.setTemperature(parseFloat(text().trim())) }
    Process {
        id: sensors
        command: ["sh", "-c", "sensors 2>/dev/null | grep -E 'Package id 0|Tctl|Tdie' | grep -oP '\\+\\K[0-9.]+(?=°C)' | head -1"]
        stdout: StdioCollector { onStreamFinished: root.setTemperature(parseFloat(text.trim())) }
    }
    Process {
        id: diskProbe
        command: ["df", "-k", "/"]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = (text.trim().split("\n")[1] ?? "").trim().split(/\s+/).map(Number);
                if (parts.length >= 4 && parts[1] > 0) root.disk = { available: true, total: parts[1], used: parts[2], free: parts[3] };
            }
        }
    }

    Timer {
        interval: 3000
        repeat: true
        triggeredOnStart: true
        running: root.gpuSampling && !root.gpu.failed
        onTriggered: if (!gpuProbe.running) gpuProbe.running = true
    }
    Process {
        id: gpuProbe
        command: ["timeout", "3", "python3", "-I", Quickshell.shellPath("tools/gpu_sample.py")]
        onExited: code => { if (code !== 0) root.gpu = Object.assign({}, root.gpu, { available: false, failed: true, error: "GPU probe failed; reopen to retry" }); }
        stdout: StdioCollector {
            onStreamFinished: {
                if (!text.trim()) return;
                try {
                    const s = JSON.parse(text);
                    const ok = s.available === true;
                    root.gpu = { available: ok, failed: !ok, usage: ok ? s.gpu : 0, temperature: ok ? s.temperature : null,
                        vramUsed: ok ? s.vramUsed : null, vramTotal: ok ? s.vramTotal : null, source: ok ? s.source : "",
                        error: s.error || "", history: ok ? root.pushHistory(root.gpu.history, s.gpu) : root.gpu.history };
                } catch (_) {
                    root.gpu = Object.assign({}, root.gpu, { available: false, failed: true, error: "Invalid GPU sample; reopen to retry" });
                }
            }
        }
    }
}
