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

    // Lock: the command the session's own binds use (Super+L, the power key). S7 decides how lock really works
    // (OPEN F2-5); until then this one stands in.
    function lock() { Quickshell.execDetached(["dms", "ipc", "call", "lock", "lock"]); }
    // Z158: suspend, reboot and power off are systemd's; log out ends the Hyprland session.
    function suspend() { Quickshell.execDetached(["systemctl", "suspend"]); }
    function logout() { Hyprland.dispatch("hl.dsp.exit()"); }
    function reboot() { Quickshell.execDetached(["systemctl", "reboot"]); }
    function powerOff() { Quickshell.execDetached(["systemctl", "poweroff"]); }
}
