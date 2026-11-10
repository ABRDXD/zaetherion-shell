import QtQuick
import Quickshell
import qs.view.cues
import qs.view.rooms
import qs.view.shell
import qs.view.ui

// The field archive's tape bookkeeping (view/rooms/FArchive.qml, ViewState.playTape; docs/OVERDRIVE.md §17): the notes
// in view are reported as spans with their wear, each second plays the tape over the notes at least half in view and
// no others, wear grows with the seconds played, nothing is counted with the fiction off, and the field book is
// printed. The tape's shader itself needs a GPU (tools/overdrive/archive_frames.py).
Scope {
    id: root
    function check(name, ok, detail) { ok ? console.log("CUE_PASS", name) : console.log("CUE_FAIL", name, JSON.stringify(detail ?? {})); }
    function after(ms, fn) {
        const timer = Qt.createQmlObject("import QtQuick; Timer {}", root);
        timer.interval = ms;
        timer.triggered.connect(() => { timer.destroy(); fn(); });
        timer.start();
    }
    function find(item, test) {
        if (!item) return null;
        if (test(item)) return item;
        for (const child of item.children ?? []) {
            const found = find(child, test);
            if (found) return found;
        }
        return null;
    }
    FloatingWindow {
        id: window
        implicitWidth: 900; implicitHeight: 700; visible: true
        Loader { id: dialog; anchors.fill: parent; active: false; source: "view/rooms/FArchive.qml" }
    }
    Component.onCompleted: after(400, () => {
        ViewState.visited = ["home", "media", "performance", "workspaces", "devices", "tasks", "timers", "clipboard", "notifications"];
        ViewState.surveyDays = Array.from({ length: 10 }, (_, i) => "2026-11-" + String(i + 1).padStart(2, "0"));
        ViewState.tapeWear = {};
        ViewState.tapeSeconds = 0;
        ViewState.noteFiled = {};
        ViewState.fieldBook = { seed: 3, day: "2026-11-09", stations: 2, total: 2, readings: [{ room: "tasks", kind: "TAB", w: 1.27, h: 0.28 }] };
        ViewState.loreEnabled = true;
        dialog.active = true;
        after(600, root.spans);
    });
    function spans() {
        const a = dialog.item, notes = find(a, i => i.contentY !== undefined && typeof i.flick === "function");
        const top = notes.mapToItem(a, 0, 0).y, bottom = top + notes.height;
        const inside = a.spans.every(s => s.y >= top - 0.5 && s.y + s.h <= bottom + 0.5);
        const labels = a.spans.map(s => s.label);
        check("archive.spans", a.spans.length >= 2 && inside && new Set(labels).size === labels.length && a.spans.every(s => s.wear === 0),
              { spans: a.spans.length, inside: inside });
        // Seen notes are filed today; their header carries the revision line.
        const d = new Date(), today = d.getFullYear() + "-" + String(d.getMonth() + 1).padStart(2, "0") + "-" + String(d.getDate()).padStart(2, "0");
        const filed = labels.every(l => ViewState.noteFiled[l] === today);
        const line = find(a, i => typeof i.text === "string" && i.text === "FILED " + today + " · REV 1");
        check("archive.revision", filed && !!line && line.visible, { filed: filed, line: !!line });
        // One second of tape: the notes at least half in view are played, nothing else.
        const shown = a.spans.filter(s => s.h >= Math.min(60, s.height * 0.5)).map(s => s.label);
        after(1150, () => {
            const worn = Object.keys(ViewState.tapeWear);
            check("archive.tape.played", ViewState.tapeSeconds >= 1 && shown.length > 0 && shown.every(l => ViewState.tapeWear[l] >= 1)
                  && worn.every(l => shown.includes(l)), { seconds: ViewState.tapeSeconds, shown: shown, worn: worn });
            root.wear(a, notes, shown);
        });
    }
    function wear(a, notes, shown) {
        const label = shown[0];
        ViewState.tapeWear = Object.assign({}, ViewState.tapeWear, { [label]: 300 });
        a.updateSpans();
        const s = a.spans.find(x => x.label === label);
        const creases = a.spans.map(x => x.crease);
        check("archive.tape.wear", Math.abs(a.wearOf(label) - (1 - Math.exp(-1))) < 1e-9 && Math.abs(s.wear - a.wearOf(label)) < 1e-9
              && creases.every(c => c >= 0.2 && c <= 0.8) && a.creaseOf(label) === a.creaseOf(label), { wear: s?.wear });
        // Scrolled to the end: the field book is printed, and the first notes leave the spans.
        notes.contentY = Math.max(0, notes.contentHeight - notes.height);
        after(200, () => {
            const book = find(a, i => i.text === "FIELD BOOK / KEPT BY THE SURVEYOR");
            const reading = find(a, i => typeof i.text === "string" && i.text.startsWith("TASKS / TAB"));
            check("archive.fieldbook", !!book && book.visible && !!reading && !a.spans.some(x => x.label === label),
                  { book: !!book, reading: reading?.text ?? null });
            // The night log: two nights, newest first; opening it again by day adds nothing.
            ViewState.nightLog = [{ night: "2026-11-08", at: "23:40", age: 0.25 }, { night: "2026-11-09", at: "02:10", age: 0.5 }];
            const h = new Date().getHours();
            ViewState.markNight();
            const log = find(a, i => typeof i.text === "string" && i.text.startsWith("NIGHT LOG / "));
            const lines = log ? log.text.split("\n") : [];
            check("archive.nightlog", !!log && log.visible && lines[1] === "2026-11-09 02:10 · FULL · 100% LIT" && lines[2] === "2026-11-08 23:40 · FIRST QUARTER · 50% LIT"
                  && ViewState.nightLog.length === ((h >= 22 || h < 6) ? 3 : 2), { lines: lines, kept: ViewState.nightLog.length });
            // With the fiction off, the tape doesn't run.
            ViewState.loreEnabled = false;
            const before = ViewState.tapeSeconds;
            after(1300, () => {
                check("archive.tape.off", ViewState.tapeSeconds === before, { before: before, now: ViewState.tapeSeconds });
                console.log("CUE_ACTIVE", Motion.active, JSON.stringify(Motion.activeNames));
                console.log("CUE_DONE");
                Qt.exit(0);
            });
        });
    }
}
