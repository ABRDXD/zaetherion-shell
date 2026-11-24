pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.view.cues

// ZÆTHERION's session lock (S7, docs/LOCK.md §2-4). Locked whenever the core says so (topic `lock`), or, while
// the core is not answering, whenever its marker is there: a view respawned after a crash re-locks at once
// (Hyprland's allow_session_lock_restore). Unlocking is only this: PAM says yes, the core is asked to release,
// and the screen drops when the core publishes the change. The core unreachable: still locked, and it says so.
Scope {
    id: root
    property var core: null   // CoreClient
    property var host: null   // HostAdapter: media and battery for the band
    // The password check, handed in by the shell (adapters/common/PamLockAuth.qml): submit(secret), busy, and the
    // accepted / rejected signals. Without one nothing can unlock.
    property var auth: null
    readonly property url faceSource: Qt.resolvedUrl("PasswordLockFace.qml")
    readonly property string markerPath: (Quickshell.env("FART_RUNTIME_DIR")
        || (Quickshell.env("XDG_RUNTIME_DIR") ?? "") + "/zaetherion") + "/locked"
    property bool markerLocked: false
    readonly property bool coreKnows: root.core?.connected === true && root.core?.lockData !== null && root.core?.lockData !== undefined
    readonly property bool locked: coreKnows ? root.core.lockData.locked === true : markerLocked
    // The compositor's own word that the session is locked (docs/LOCK.md checks read it).
    readonly property bool secure: session.secure

    // What every screen shows (LockScreen reads these).
    property int maskLength: 0
    property int attempts: 0
    property real rejectionMs: -1
    property string notice: ""
    property real holdProgress: 0
    readonly property string wallpaper: root.core?.wallpaperData?.applied ?? ""
    readonly property var track: root.host?.media?.active ?? null
    readonly property real batteryFraction: root.host?.power?.battery?.available ? root.host.power.battery.level : -1

    FileView {
        path: root.markerPath
        watchChanges: true
        printErrors: false
        onLoaded: root.markerLocked = true
        onLoadFailed: root.markerLocked = false
        onFileChanged: reload()
    }

    Connections {
        target: root.auth
        function onAccepted() { root.release(); }
        function onRejected(why) { root.reject(); }
    }

    function typing(length) {
        maskLength = length;
        if (length > 0 && rejectionMs >= 320) rejectionMs = -1;  // typing again clears the error
    }
    function submit(secret) {
        if (!locked || !root.auth || root.auth.busy || secret === "")
            return;
        maskLength = 0;
        root.auth.submit(secret);
    }
    function reject() {
        attempts += 1;
        rejectionMs = 0;
        shake.restart();  // 320 ms; the face keeps still when reduced
    }
    function release() {
        notice = "";
        if (!root.core?.connected) {
            notice = "> CORE NOT ANSWERING · STILL LOCKED · TRY AGAIN";
            return;
        }
        root.core.request("lock.release", {}, (ok, result) => {
            if (!ok) notice = "> " + String(result?.message ?? "COULD NOT UNLOCK").toUpperCase() + " · STILL LOCKED";
        });
    }
    function media(action) {
        const m = root.host?.media;
        if (!m) return;
        if (action === "previous") m.previous();
        else if (action === "next") m.next();
        else m.togglePlaying();
    }
    // Hold-to-confirm power (Z36): a full 1 s hold opens a small choice, Suspend / Restart / Power off (owner,
    // 24 Nov). Releasing early cancels. The lock stays up whatever is picked; suspend resumes to it.
    property bool powerChoice: false
    function holdStart() { holdProgress = 0; hold.restart(); }
    function holdEnd() { hold.stop(); holdProgress = 0; }
    function power(action) {
        powerChoice = false;
        const p = root.host?.power;
        if (!p) return;
        if (action === "suspend") p.suspend();
        else if (action === "reboot") p.reboot();
        else if (action === "poweroff") p.powerOff();
    }

    NumberAnimation { id: shake; target: root; property: "rejectionMs"; from: 0; to: 320; duration: 320 }
    NumberAnimation {
        id: hold; target: root; property: "holdProgress"; from: 0; to: 1; duration: 1000
        onFinished: if (root.holdProgress >= 1) { root.holdProgress = 0; root.powerChoice = true; }
    }
    Activity { name: "lock.shake"; running: shake.running }
    Activity { name: "lock.hold"; running: hold.running }

    onLockedChanged: {
        if (!locked) {
            powerChoice = false;
            attempts = 0;
            rejectionMs = -1;
            maskLength = 0;
            notice = "";
        }
    }

    WlSessionLock {
        id: session
        locked: root.locked
        WlSessionLockSurface {
            color: "#06070a"
            LockScreen {
                anchors.fill: parent
                lock: root
            }
        }
    }
}
