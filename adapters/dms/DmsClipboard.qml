import QtQuick
import qs.view.contract
import "DmsClipMap.js" as ClipMap

// DMS's own clipboard history as FART's clipboard (Z202; owner, 15 November 2026: "quickpaste should just use DMS's
// own clipboard history"). DMS records, keeps, pins and pastes; this domain only shows it. It reads nothing unless
// "history" is leased: the `clipboard` subscription follows the lease, every call checks it, and entries, ids and
// pictures are dropped when it ends (docs/DMS_ADAPTER.md §8). Contents are never logged. The calls are DMS's
// ClipboardService's (MIT, NOTICE).
ClipboardDomain {
    id: root
    required property DmsLink link
    readonly property bool reading: holds("history")
    readonly property DmsFeed feed: DmsFeed { link: root.link; service: "clipboard"; capability: "clipboard"; wanted: root.reading }
    available: feed.usable
    pinsKept: true
    // Whether the window that will receive the paste keystroke is a terminal (Ctrl+Shift+V): the session's answer.
    property var terminalFocused: () => false
    // DMS's own wait between the copy and the keystroke, so the surface that chose the clip has let go of the keyboard.
    readonly property int pasteDelay: 200
    // DMS can send the keystroke itself (`clipboard.pasteSupported`); without it, paste only copies.
    property bool pasteSupported: false
    readonly property bool linkReady: link.ready
    onLinkReadyChanged: checkPaste()
    Component.onCompleted: checkPaste()
    function checkPaste() {
        if (!linkReady) {
            pasteSupported = false;
            return;
        }
        link.call("clipboard.pasteSupported", undefined, (result, error) => {
            root.pasteSupported = !error && result?.supported === true;
        });
    }

    // Our string id -> DMS's own id, for the entries on show.
    property var dmsIds: ({})
    function dmsId(id) { return reading ? dmsIds[id] : undefined; }
    readonly property var snapshot: feed.data
    // A snapshot without a list (DMS's history off: `history: null`) is no news, not an empty history.
    onSnapshotChanged: if (Array.isArray(snapshot?.history)) apply(snapshot.history)
    onReadingChanged: {
        if (reading) {
            refresh();
            return;
        }
        entries = [];
        dmsIds = {};
        loaded = false;
        thumbQueue = [];
        thumbLoading = "";
        thumbnails = {};
    }
    function apply(history) {
        if (!reading)
            return;
        dmsIds = ClipMap.ids(history);
        entries = ClipMap.entries(history);
        loaded = true;
    }

    function refresh() {
        if (!reading)
            return;
        link.call("clipboard.getHistory", undefined, (result, error) => {
            if (!error)
                root.apply(result ?? []);
        });
    }
    function copy(id: string) {
        const entry = dmsId(id);
        if (entry !== undefined)
            link.call("clipboard.copyEntry", { id: entry }, () => {});
    }
    function paste(id: string) {
        const entry = dmsId(id);
        if (entry === undefined)
            return;
        link.call("clipboard.copyEntry", { id: entry }, (result, error) => {
            if (!error && root.pasteSupported)
                pasteTimer.restart();
        });
    }
    Timer {
        id: pasteTimer
        interval: root.pasteDelay
        onTriggered: root.link.call("clipboard.sendPaste", { shift: root.terminalFocused() === true }, () => {})
    }
    function remove(id: string) {
        const entry = dmsId(id);
        if (entry !== undefined)
            link.call("clipboard.deleteEntry", { id: entry }, () => root.refresh());
    }
    function pin(id: string, on: bool) {
        const entry = dmsId(id);
        if (entry !== undefined)
            link.call(on ? "clipboard.pinEntry" : "clipboard.unpinEntry", { id: entry }, () => root.refresh());
    }
    function copyText(text: string) {
        link.call("clipboard.copy", { text: text }, () => {});
    }
    function fetchText(id: string) {
        const entry = dmsId(id);
        if (entry === undefined)
            return;
        link.call("clipboard.getEntry", { id: entry }, (result, error) => {
            if (error || !root.reading)
                return;
            const data = typeof result?.data === "string" ? result.data.replace(/\s+/g, "") : "";
            root.textFetched(id, data ? ClipMap.utf8(Qt.atob(data)) : String(result?.preview ?? ""));
        });
    }

    // Pictures only for rows on screen (Z79), one at a time, kept in memory as data URLs, never on disk.
    property var thumbQueue: []
    property string thumbLoading: ""
    function requestThumbnail(id: string) {
        if (dmsId(id) === undefined || thumbnails[id] || thumbQueue.includes(id) || thumbLoading === id)
            return;
        thumbQueue = thumbQueue.concat([id]);
        nextThumbnail();
    }
    function nextThumbnail() {
        if (thumbLoading !== "" || thumbQueue.length === 0)
            return;
        const id = thumbQueue[0];
        thumbQueue = thumbQueue.slice(1);
        const entry = dmsId(id);
        if (entry === undefined) {
            nextThumbnail();
            return;
        }
        thumbLoading = id;
        link.call("clipboard.getEntry", { id: entry }, (result, error) => {
            if (root.thumbLoading !== id)
                return;
            root.thumbLoading = "";
            const url = error ? "" : ClipMap.imageUrl(result);
            if (url && root.reading)
                root.thumbnails = Object.assign({}, root.thumbnails, { [id]: url });
            root.nextThumbnail();
        });
    }
}
