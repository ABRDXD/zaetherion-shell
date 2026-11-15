import QtQuick
import Quickshell.Io

// Runs argv lists one after another, never through a shell; a non-zero exit drops the rest. One queue at a time:
// run() while busy is ignored, so a second click cannot interleave with the first.
QtObject {
    id: root
    property var pending: []
    readonly property bool busy: process.running || pending.length > 0
    signal finished(bool ok)

    function run(commands: var): void {
        if (busy || !commands || !commands.length)
            return;
        pending = commands.slice(1);
        process.command = commands[0];
        process.running = true;
    }
    readonly property Process process: Process {
        onExited: (code, status) => {
            if (code !== 0 || !root.pending.length) {
                root.pending = [];
                root.finished(code === 0);
                return;
            }
            command = root.pending[0];
            root.pending = root.pending.slice(1);
            running = true;
        }
    }
}
