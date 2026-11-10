import QtQuick
import Quickshell
import Quickshell.Io
import qs.view.contract

// cliphist history. Entries are read only while "history" is leased; contents are never logged.
ClipboardDomain {
    id: root
    readonly property bool reading: holds("history")
    available: true
    onReadingChanged: if (reading) refresh(); else { entries = []; lines = {}; }
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
    function remove(id: string) {
        if (!lines[id]) return;
        remover.command = ["sh", "-c", 'printf "%s" "$1" | cliphist delete', "fart-clip", lines[id]];
        remover.running = true;
    }
    function copyText(text: string) { Quickshell.clipboardText = text; }
    function fetchText(id: string) {
        if (!valid(id) || fetcher.running) return;
        fetcher.entryId = id;
        fetcher.command = ["sh", "-c", 'cliphist decode "$1" | head -c 20000', "fart-clip", id];
        fetcher.running = true;
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
            }
        }
    }
    Process { id: remover; onExited: root.refresh() }
    Process {
        id: fetcher
        property string entryId: ""
        stdout: StdioCollector { onStreamFinished: root.textFetched(fetcher.entryId, text) }
    }
}
