import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import qs.view.contract

PowerDomain {
    id: root
    required property var settings
    readonly property var display: settings.values.display || {}
    readonly property var profileNames: ({ [PowerProfile.PowerSaver]: "power-saver", [PowerProfile.Balanced]: "balanced", [PowerProfile.Performance]: "performance" })
    available: true
    battery: ({
        available: UPower.displayDevice.ready && UPower.displayDevice.isLaptopBattery,
        level: UPower.displayDevice.percentage,
        charging: UPower.displayDevice.state === UPowerDeviceState.Charging,
        pluggedIn: !UPower.onBattery
    })
    profile: profileNames[PowerProfiles.profile] ?? ""
    profiles: PowerProfiles.hasPerformanceProfile ? ["power-saver", "balanced", "performance"] : ["power-saver", "balanced"]
    idleInhibited: settings.values.idle?.manualInhibit === true
    nightLight: display.enabled === true || Object.values(display.monitors || {}).some(m => m.enabled)

    function setProfile(name: string) {
        const value = Object.keys(profileNames).find(k => profileNames[k] === name);
        if (value !== undefined && profiles.includes(name)) PowerProfiles.profile = Number(value);
    }
    // The host offers toggles only; toggle when the requested state differs.
    function setIdleInhibited(on: bool) { if (on !== idleInhibited) Quickshell.execDetached(["serpantinum", "set", "idle", "caffeine", "toggle"]); }
    function setNightLight(on: bool) { if (on !== nightLight) Quickshell.execDetached(["serpantinum", "msg", "open", "system"]); }
    function setBrightness(level: real) {
        if (!brightness.available) return;
        Quickshell.execDetached(["serpantinum", "brightness", "set", String(Math.round(Math.max(0, Math.min(1, level)) * 100))]);
    }
    function lock() { Quickshell.execDetached(["serpantinum", "lock"]); }

    // Brightness: the host's runtime file while leased, with one probe to discover support.
    readonly property bool brightnessHeld: holds("brightness")
    onBrightnessHeldChanged: if (brightnessHeld) brightnessProbe.running = true; else brightnessProbe.running = false
    function setLevel(text) {
        const value = Number(String(text).trim());
        if (String(text).trim() !== "" && Number.isFinite(value) && value >= 0 && value <= 100) brightness = { available: true, level: value / 100 };
    }
    FileView {
        path: root.brightnessHeld ? root.settings.runDir + "/brightness" : ""
        printErrors: false
        watchChanges: root.brightnessHeld
        onFileChanged: reload()
        onLoaded: root.setLevel(text())
    }
    Process {
        id: brightnessProbe
        command: ["timeout", "6", "serpantinum", "brightness", "get"]
        stdout: StdioCollector { onStreamFinished: root.setLevel(text) }
    }
}
