import QtQuick
import Quickshell.Services.UPower

// Battery and power profile from UPower. A DMS-backed PowerDomain composes it (DMS_ADAPTER.md §5).
QtObject {
    id: root
    readonly property var profileNames: ({ [PowerProfile.PowerSaver]: "power-saver", [PowerProfile.Balanced]: "balanced", [PowerProfile.Performance]: "performance" })
    readonly property var battery: ({
        available: UPower.displayDevice.ready && UPower.displayDevice.isLaptopBattery,
        level: UPower.displayDevice.percentage,
        charging: UPower.displayDevice.state === UPowerDeviceState.Charging,
        pluggedIn: !UPower.onBattery
    })
    readonly property string profile: profileNames[PowerProfiles.profile] ?? ""
    readonly property var profiles: PowerProfiles.hasPerformanceProfile ? ["power-saver", "balanced", "performance"] : ["power-saver", "balanced"]

    function setProfile(name: string) {
        const value = Object.keys(profileNames).find(k => profileNames[k] === name);
        if (value !== undefined && profiles.includes(name)) PowerProfiles.profile = Number(value);
    }
}
