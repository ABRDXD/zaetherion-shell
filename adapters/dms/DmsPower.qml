import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.adapters.quickshell
import qs.view.contract

// PowerDomain for the ZÆTHERION session (docs/DMS_ADAPTER.md §5). Battery and profile come from UPower
// (adapters/quickshell); the session card's actions are the same commands DMS's power menu runs (Z158).
// Brightness, night light and idle inhibit come from DMS (step 5 of the S2 plan).
PowerDomain {
    id: root
    readonly property QuickshellPowerSource source: QuickshellPowerSource {}
    available: true
    battery: source.battery
    profile: source.profile
    profiles: source.profiles

    function setProfile(name: string) { source.setProfile(name); }
    function setIdleInhibited(on: bool) {}
    function setBrightness(level: real) {}
    function setNightLight(on: bool) {}
    function lock() {}
    function suspend() {}
    function logout() {}
    function reboot() {}
    function powerOff() {}
}
