import qs.view.cues
import QtQuick
import Quickshell
import Quickshell.Io

// The heavy layer's keeper (docs/OVERDRIVE.md §33). While Overdrive runs and the panel is open it keeps a second process alive on the NVIDIA card
// (shell-heavy.qml) and tells it where to draw over one socket; the process ends with the lease. `up` once the card has drawn its first frames.
Scope {
    id: root
    // { edge, full, width, height, cx, cy, radius, elevation } of what's asked for, or null when there is nothing to draw.
    property var scene: null
    property bool opened: false
    readonly property bool enabled: (Quickshell.env("FART_HEAVY") ?? "1") !== "0"
    readonly property bool wanted: enabled && opened && Motion.overdrive && !Motion.reduced
    readonly property string socketPath: (Quickshell.env("XDG_RUNTIME_DIR") ?? "/tmp") + "/fart-heavy.sock"
    property var peer: null
    property bool ready: false
    readonly property bool up: wanted && ready
    readonly property bool showing: up && scene !== null
    readonly property string message: JSON.stringify(Object.assign({ showing: showing }, scene ?? {}))
    onMessageChanged: send()
    function send() {
        if (peer) {
            peer.write(message + "\n");
            peer.flush();
        }
    }
    onWantedChanged: if (!wanted) { ready = false; peer = null; }
    SocketServer {
        active: root.wanted
        path: root.socketPath
        handler: Socket {
            id: link
            parser: SplitParser { onRead: data => { if (data === "ready") { root.ready = true; } } }
            onConnectedChanged: {
                if (connected) {
                    root.peer = link;
                    root.send();
                } else if (root.peer === link) {
                    root.peer = null;
                    root.ready = false;
                }
            }
        }
    }
    Process {
        running: root.wanted
        command: ["qs", "-n", "--no-color", "-p", Quickshell.shellDir + "/shell-heavy.qml"]
        // FART_HEAVY_CARD=integrated keeps it on the AMD chip: for checks on battery, where waking the NVIDIA card isn't worth it.
        environment: (Quickshell.env("FART_HEAVY_CARD") ?? "") === "integrated" ? ({ FART_HEAVY_SOCKET: root.socketPath }) : ({
            FART_HEAVY_SOCKET: root.socketPath,
            __NV_PRIME_RENDER_OFFLOAD: "1",
            __GLX_VENDOR_LIBRARY_NAME: "nvidia",
            __EGL_VENDOR_LIBRARY_FILENAMES: "/usr/share/glvnd/egl_vendor.d/10_nvidia.json",
            __VK_LAYER_NV_optimus: "NVIDIA_only"
        })
    }
}
