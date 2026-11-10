import qs.view.contract
import QtQuick

// Performance as a planet: the CPU load, then memory and disk. It takes no lease of its own: it reads
// the samples the orbit's Performance system already leases while the overview is open, and shows a
// dash until the first one arrives.
Face {
    id: root
    required property HostAdapter host
    readonly property var cpu: host.system.cpu
    readonly property var memory: host.system.memory
    readonly property var disk: host.system.disk
    function percent(on, ratio) { return on ? Math.round(Math.max(0, Math.min(1, ratio)) * 100) + "%" : "–"; }

    figure: percent(cpu.available, cpu.usage)
    brief: "CPU " + figure
    note: "CPU" + (cpu.temperature != null ? " · " + Math.round(cpu.temperature) + "°" : "")
    detail: "MEM " + percent(memory.available, memory.used / Math.max(1, memory.total)) + " · DISK " + percent(disk.available, disk.used / Math.max(1, disk.total))

    Accessible.role: Accessible.StaticText
    Accessible.name: cpu.available ? "CPU " + figure : "CPU not sampled"
}
