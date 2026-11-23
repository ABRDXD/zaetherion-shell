import QtQuick
import Quickshell
import Quickshell.Io
import qs.view.contract

// cliphist history. Entries are read only while "history" is leased; contents are never logged.
ClipboardDomain {
    id: root
    readonly property bool reading: holds("history")
    available: true
    onReadingChanged: {
        if (reading) {
            refresh();
            return;
        }
        entries = [];
        lines = {};
        loaded = false;
        dropThumbnails();
    }
    function parse(line) {
        const id = line.split("\t")[0];
        return { id: id, text: line.replace(/^\s*\S+\s+/, ""), isImage: /^\d+\t\[\[.*binary data.*\d+x\d+.*\]\]$/.test(line) };
    }
    // cliphist resolves entries from their exact list line.
    property var lines: ({})
    function valid(id) { return /^\d+$/.test(id); }
    function refresh() { if (reading && !lister.running) lister.running = true; }
    function copy(id: string) {
        if (lines[id]) Quickshell.execDetached(["sh", "-c", 'printf "%s" "$1" | cliphist decode | wl-copy', "fart-clip", lines[id]]);
    }
    // The paste keystroke, given by the session's adapter (Hyprland's send_shortcut on DMS): called with true
    // when the window that will receive it is a terminal (Ctrl+Shift+V). Without one, paste only copies.
    property var sendPaste: null
    // Which window will receive the keystroke: the adapter's answer, read when the keystroke goes.
    property var terminalFocused: () => false
    // DMS waits 200 ms after the copy before the keystroke, so the surface that chose the clip has let go of the
    // keyboard and the window underneath has it back (Z117).
    readonly property int pasteDelay: 200
    function paste(id: string) {
        if (!lines[id]) return;
        paster.command = ["sh", "-c", 'printf "%s" "$1" | cliphist decode | wl-copy', "fart-clip", lines[id]];
        paster.running = true;
    }
    function remove(id: string) {
        if (!lines[id]) return;
        remover.command = ["sh", "-c", 'printf "%s" "$1" | cliphist delete', "fart-clip", lines[id]];
        remover.running = true;
    }
    function copyText(text: string) { Quickshell.clipboardText = text; }
    // cliphist keeps no pins: FART's own (ClipPins) stand in, so nothing calls this.
    function pin(id: string, on: bool) {}
    // cliphist has no settings of its own to show (config stays null) and is cleared outside FART.
    function setConfig(key: string, value: var) {}
    function clearHistory() {}
    function fetchText(id: string) {
        if (!valid(id) || fetcher.running) return;
        fetcher.entryId = id;
        fetcher.command = ["sh", "-c", 'cliphist decode "$1" | head -c 20000', "fart-clip", id];
        fetcher.running = true;
    }
    // Image clips are decoded only when a visible row asks (Z79), one at a time, into a private folder under the
    // runtime directory (tmpfs, never the home folder); the folder goes when the lease does.
    readonly property string thumbDir: (Quickshell.env("XDG_RUNTIME_DIR") ?? "/tmp") + "/zaetherion/clips"
    property var thumbQueue: []
    function requestThumbnail(id: string) {
        if (!reading || !valid(id) || thumbnails[id] || thumbQueue.includes(id) || thumbnailer.entryId === id) return;
        thumbQueue = thumbQueue.concat([id]);
        nextThumbnail();
    }
    function nextThumbnail() {
        if (thumbnailer.running || thumbQueue.length === 0) return;
        const id = thumbQueue[0];
        thumbQueue = thumbQueue.slice(1);
        thumbnailer.entryId = id;
        thumbnailer.command = ["sh", "-c", 'umask 077 && mkdir -p "$1" && cliphist decode "$2" > "$1/$2.img"', "fart-clip", thumbDir, id];
        thumbnailer.running = true;
    }
    function dropThumbnails() {
        thumbQueue = [];
        thumbnails = {};
        Quickshell.execDetached(["rm", "-rf", "--", thumbDir]);
    }
    Process {
        id: lister
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (!root.reading) return;
                const rows = text.trim() ? text.trim().split("\n") : [];
                const byId = {};
                for (const row of rows) byId[row.split("\t")[0]] = row;
                root.lines = byId;
                root.entries = rows.map(l => root.parse(l));
                root.loaded = true;
            }
        }
    }
    Process { id: remover; onExited: root.refresh() }
    Process {
        id: paster
        onExited: (code) => { if (code === 0 && root.sendPaste) pasteTimer.restart(); }
    }
    Timer {
        id: pasteTimer
        interval: root.pasteDelay
        onTriggered: root.sendPaste?.(root.terminalFocused())
    }
    Process {
        id: fetcher
        property string entryId: ""
        stdout: StdioCollector { onStreamFinished: root.textFetched(fetcher.entryId, text) }
    }
    Process {
        id: thumbnailer
        property string entryId: ""
        onExited: code => {
            const id = entryId;
            entryId = "";
            if (code === 0 && root.reading)
                root.thumbnails = Object.assign({}, root.thumbnails, { [id]: "file://" + root.thumbDir + "/" + id + ".img" });
            root.nextThumbnail();
        }
    }
}
