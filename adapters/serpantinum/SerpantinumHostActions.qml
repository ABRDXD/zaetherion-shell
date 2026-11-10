import QtQuick
import Quickshell
import Quickshell.Io
import qs.view.contract

HostActionsDomain {
    id: root
    readonly property var routes: ({
        launcher: ["msg", "open", "launcher"], clipboard: ["msg", "open", "clipboard"],
        settings: ["settings"], themes: ["settings", "theme"], wallpapers: ["msg", "open", "wallpaper"],
        wifi: ["msg", "open", "network", "wifi"], bluetooth: ["msg", "open", "network", "bt"],
        notifications: ["msg", "open", "notifications"], power: ["msg", "open", "system"],
        display: ["msg", "open", "system"], music: ["msg", "open", "music"],
        calendar: ["msg", "open", "calendar"], updates: ["settings", "about"]
    })
    readonly property string recordingHelper: Quickshell.shellPath("tools/recording_control.py")
    available: true
    name: "serpantinum"
    version: "2.4.1"
    targets: Object.keys(routes)
    // Serpantinum 2.4.1 `msg open launcher` takes no query; FART does not patch the host for it.
    launcherAcceptsQuery: false

    function open(target: string) { if (routes[target]) Quickshell.execDetached(["serpantinum", ...routes[target]]); }
    function openLauncher(query: string) { open("launcher"); }
    function checkUpdates() { if (!updateCheck.running) updateCheck.running = true; }
    function capture() { Quickshell.execDetached(["python3", "-I", recordingHelper, "capture"]); }
    function setRecording(on: bool) { Quickshell.execDetached(["python3", "-I", recordingHelper, on ? "start" : "stop"]); }

    Process {
        id: updateCheck
        command: ["serpantinum", "info", "updates", "--json"]
        onRunningChanged: root.updates = Object.assign({}, root.updates, { checking: running })
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const result = JSON.parse(text);
                    root.updates = { available: !!result.remote, checking: false, count: result.has_update ? 1 : 0 };
                } catch (_) { root.updates = { available: false, checking: false, count: 0 }; }
            }
        }
    }
    Timer {
        interval: 1500; repeat: true; triggeredOnStart: true; running: root.holds("recording")
        onTriggered: if (!recordingProbe.running) recordingProbe.running = true
    }
    Process {
        id: recordingProbe
        command: ["python3", "-I", root.recordingHelper, "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                const startedAt = Number(text.trim()) || 0;
                root.recording = { available: true, active: startedAt > 0, startedAt: startedAt };
            }
        }
    }
}
