import QtQuick
import Quickshell
import Quickshell.Io
import qs.view.contract

// Lyrics for the active track: host cache (read-only) -> FART cache -> fetch. Timing lives in the view.
LyricsDomain {
    id: root
    required property MediaDomain media
    // Directory of md5("Artist - Title").json files owned by the host; "" when the host keeps none.
    property string hostCacheDir: ""
    readonly property string fartCacheDir: (Quickshell.env("FART_CACHE_DIR") || (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/fart") + "/lyrics"
    readonly property var track: media.active
    readonly property string key: track && track.title && track.artist ? track.artist.trim() + " - " + track.title.trim() : ""
    readonly property bool wanted: holds("lyrics")
    property string loadedKey: ""
    available: true

    function normalise(raw, length) {
        const lines = (Array.isArray(raw) ? raw : []).map(l => ({
            time: Number(l.time) || 0, text: String(l.text ?? ""),
            words: (Array.isArray(l.words) ? l.words : []).map(w => ({ time: Number(w.time) || 0, end: Number(w.endTime ?? w.end) || 0, text: String(w.text ?? "") }))
        })).sort((a, b) => a.time - b.time);
        return lines.map((l, i) => Object.assign(l, { end: lines[i + 1]?.time ?? Math.max(l.time + 5, length || 0) }));
    }
    function accept(raw, from) {
        const parsed = normalise(raw, track?.length ?? 0);
        if (parsed.length === 0) return false;
        lines = parsed;
        wordTimed = parsed.some(l => l.words.length > 0);
        source = from;
        status = "ok";
        return true;
    }
    function clear(state) {
        fetcher.running = false;
        lines = [];
        wordTimed = false;
        source = "";
        status = state;
    }
    function start() {
        if (!wanted || key === loadedKey) return;
        loadedKey = key;
        trackKey = key;
        if (!key) { clear("no-track"); return; }
        clear("loading");
        if (hostCacheDir) hostFile.path = hostCacheDir + "/" + Qt.md5(key) + ".json";
        else fetch();
    }
    function fetch() {
        if (loadedKey !== key || !key) return;
        fetcher.requestKey = key;
        fetcher.command = ["python3", "-I", Quickshell.shellPath("tools/lyrics/lyrics.py"), track.title, track.artist,
            String(Math.floor(track.length || 0)), "--cache-dir", fartCacheDir];
        fetcher.running = true;
    }
    function reload() { loadedKey = ""; hostFile.path = ""; start(); }
    // A local .lrc or .ttml, parsed by the same tool as fetched lyrics (enhanced-LRC and TTML words kept).
    function loadLocal(path: string) {
        localParser.running = false;
        localParser.command = ["python3", "-I", Quickshell.shellPath("tools/lyrics/lyrics.py"), "--file", path.replace(/^file:\/\//, "")];
        localParser.running = true;
    }
    onKeyChanged: debounce.restart()
    onWantedChanged: {
        if (wanted) { start(); return; }
        // An unfinished lookup restarts on the next lease; finished results are kept.
        fetcher.running = false;
        if (status === "loading") loadedKey = "";
    }
    Timer { id: debounce; interval: 150; onTriggered: root.start() }
    FileView {
        id: hostFile
        printErrors: false
        onLoaded: { let raw = null; try { raw = JSON.parse(text()); } catch (_) {} if (!root.accept(raw, "host-cache")) root.fetch(); }
        onLoadFailed: root.fetch()
    }
    Process {
        id: localParser
        stdout: StdioCollector {
            onStreamFinished: {
                let result = null;
                try { result = JSON.parse(text); } catch (_) {}
                fetcher.running = false;
                if (!result || !root.accept(result.lines, "local")) root.status = "none";
            }
        }
    }
    Process {
        id: fetcher
        property string requestKey: ""
        stdout: StdioCollector {
            onStreamFinished: {
                if (fetcher.requestKey !== root.loadedKey) return;
                let result = null;
                try { result = JSON.parse(text); } catch (_) {}
                if (!result || result.status !== "ok" || !root.accept(result.lines, result.source)) root.status = result?.status === "no-track" ? "no-track" : "none";
            }
        }
    }
}
