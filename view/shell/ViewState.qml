pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../rooms/NightLog.js" as NightLog

Singleton {
    id: root
    // UI drafts survive page unloading; system state belongs to existing services.
    property var removedTask: null
    property string taskDraft: ""
    property string taskFilter: "active"
    property string taskList: "default"
    property string clipQuery: ""
    property string clipFilter: "all"
    property string timerKind: "countdown"
    property bool motionEnabled: true
    property bool ambientEnabled: true
    property bool loreEnabled: false
    // The panel covers the whole screen instead of floating at its window size (F11, Instrument settings).
    property bool fullscreen: false
    // The Media room's spectrum band, while something plays.
    property bool visualiserEnabled: true
    property var visited: []
    // The days (YYYY-MM-DD) the field archive was opened with its fiction on: the survey log's day count.
    property var surveyDays: []
    function markSurveyDay() {
        if (!loreEnabled || !loaded)
            return;
        const d = new Date(), day = d.getFullYear() + "-" + String(d.getMonth() + 1).padStart(2, "0") + "-" + String(d.getDate()).padStart(2, "0");
        if (surveyDays.includes(day))
            return;
        surveyDays = [...surveyDays, day].slice(-64);
        save.restart();
    }
    // The False Room's spent condition sets (docs/OVERDRIVE.md §53, Claude A): signatures only, sixteen kept.
    property var falseRoomSpent: []
    // The night log (docs/OVERDRIVE.md §48): the moon each night the archive is opened late, thirty nights kept.
    property var nightLog: []
    function markNight() {
        if (!loreEnabled || !loaded)
            return;
        const next = NightLog.log(nightLog, new Date());
        if (next.length === nightLog.length && next.every((e, i) => e === nightLog[i]))
            return;
        nightLog = next;
        save.restart();
    }
    // The surveyor's field book (view/rooms/Survey.js), written while it wanders the panel in Overdrive and read in
    // the field archive: room ids, kinds of control, sizes and dates only. Saved at most every 20 s.
    property var fieldBook: null
    function writeFieldBook(book) {
        fieldBook = book;
        saveLater();
    }
    // The archive's tape (view/strata/Tape.qml): the seconds each note has been played (in view while the archive is
    // open), by its label, and the counter, which is never rewound. Worn passages play back worse in Overdrive.
    property var tapeWear: ({})
    property int tapeSeconds: 0
    // The day each note was first filed (first seen in the archive): its revision history (SurveyorNotes.revision).
    property var noteFiled: ({})
    function fileNotes(labels) {
        const d = new Date(), day = d.getFullYear() + "-" + String(d.getMonth() + 1).padStart(2, "0") + "-" + String(d.getDate()).padStart(2, "0");
        const fresh = labels.filter(l => !noteFiled[l]);
        if (fresh.length === 0)
            return;
        const next = Object.assign({}, noteFiled);
        for (const l of fresh)
            next[l] = day;
        noteFiled = next;
        saveLater();
    }
    function playTape(labels) {
        const next = Object.assign({}, tapeWear);
        for (const label of labels)
            next[label] = Math.min(999999, (next[label] ?? 0) + 1);
        tapeWear = next;
        tapeSeconds += 1;
        saveLater();
    }
    function cleanWear(data) {
        const out = {};
        if (!data || typeof data !== "object" || Array.isArray(data))
            return out;
        for (const key of Object.keys(data).slice(0, 64))
            if (key.length <= 32 && Number.isFinite(data[key]) && data[key] >= 0)
                out[key] = Math.floor(data[key]);
        return out;
    }
    // Groove geometry (view/rooms/Groove.js): each track's groove, for this session only; never saved. Twenty tracks.
    property var grooves: ({})
    function keepGroove(track, groove) {
        const next = Object.assign({}, grooves);
        delete next[track];
        next[track] = groove;
        const keys = Object.keys(next);
        for (const k of keys.slice(0, Math.max(0, keys.length - 20)))
            delete next[k];
        grooves = next;
    }
    // Phantom ports (view/rooms/Ports.js): the devices Devices has seen, for this session only; never saved.
    property var deviceSightings: ({})
    // History that changes often (the field book, the tape) is saved at most every 20 s.
    function saveLater() {
        if (loaded && !lazySave.running)
            lazySave.start();
    }
    property Timer lazySave: Timer {
        interval: 20000
        onTriggered: root.persist()
    }
    // Each room's place on the orbit ({ id: radians }), kept so the system always looks the same
    // (docs/ORBIT.md §2). null: every room on the default spiral.
    property var orbitAngles: null
    property bool loaded: false
    function visit(page) {
        if (!loreEnabled)
            return;
        if (visited.includes(page))
            return;
        visited = [...visited, page];
        save.restart();
    }
    // Only known room ids with finite angles survive a load; anything else falls back to the spiral.
    // The Codex: which sheet is showing, and the modifier keys physically held while the panel has the keyboard.
    property string codexTab: "keys"
    property var heldModifiers: []
    readonly property var orbitRooms: ["media", "performance", "workspaces", "devices", "tasks", "timers", "clipboard", "notifications", "codex"]
    function cleanAngles(data) {
        if (!data || typeof data !== "object" || Array.isArray(data))
            return null;
        const out = {};
        for (const id of orbitRooms)
            if (Number.isFinite(data[id]))
                out[id] = data[id];
        return Object.keys(out).length > 0 ? out : null;
    }
    function persist() {
        if (loaded)
            save.restart();
    }
    onMotionEnabledChanged: persist()
    onAmbientEnabledChanged: persist()
    onLoreEnabledChanged: persist()
    onFullscreenChanged: persist()
    onVisualiserEnabledChanged: persist()
    onOrbitAnglesChanged: persist()
    Timer {
        id: save
        interval: 400
        onTriggered: preferences.setText(JSON.stringify({
                                                            version: 1,
                                                            motion: root.motionEnabled,
                                                            ambient: root.ambientEnabled,
                                                            lore: root.loreEnabled,
                                                            fullscreen: root.fullscreen,
                                                            visualiser: root.visualiserEnabled,
                                                            visited: root.visited,
                                                            surveyDays: root.surveyDays,
                                                            fieldBook: root.fieldBook,
                                                            tapeWear: root.tapeWear,
                                                            tapeSeconds: root.tapeSeconds,
                                                            noteFiled: root.noteFiled,
                                                            nightLog: root.nightLog,
                                                            falseRoomSpent: root.falseRoomSpent,
                                                            orbitAngles: root.orbitAngles
                                                        }))
    }
    FileView {
        id: preferences
        path: Directories.fartState.replace("file://", "") + "/preferences.json"
        printErrors: false
        onLoaded: {
            try {
                const data = JSON.parse(text());
                root.motionEnabled = data.motion !== false;
                root.ambientEnabled = data.ambient !== false;
                root.loreEnabled = data.lore === true;
                root.fullscreen = data.fullscreen === true;
                root.visualiserEnabled = data.visualiser !== false;
                root.visited = Array.isArray(data.visited) ? data.visited.filter(p => typeof p
                                                                                      === "string").slice(0,
                                                                                                          16) : [];
                root.nightLog = NightLog.clean(data.nightLog);
                root.falseRoomSpent = Array.isArray(data.falseRoomSpent) ? data.falseRoomSpent.filter(s => typeof s === "string" && s.length <= 64).slice(-16) : [];
                root.surveyDays = Array.isArray(data.surveyDays) ? data.surveyDays.filter(d => typeof d === "string" && /^\d{4}-\d{2}-\d{2}$/.test(d)).slice(-64) : [];
                root.orbitAngles = root.cleanAngles(data.orbitAngles);
                root.fieldBook = data.fieldBook && typeof data.fieldBook === "object" && !Array.isArray(data.fieldBook) ? data.fieldBook : null;
                root.tapeWear = root.cleanWear(data.tapeWear);
                root.tapeSeconds = Number.isFinite(data.tapeSeconds) && data.tapeSeconds >= 0 ? Math.floor(data.tapeSeconds) : 0;
                const filed = data.noteFiled && typeof data.noteFiled === "object" && !Array.isArray(data.noteFiled) ? data.noteFiled : {};
                root.noteFiled = Object.keys(filed).slice(0, 64).filter(k => k.length <= 32 && /^\d{4}-\d{2}-\d{2}$/.test(filed[k]))
                    .reduce((m, k) => { m[k] = filed[k]; return m; }, {});
            } catch (error) {
                console.warn("FART preferences: using defaults", error);
            }
            root.loaded = true;
        }
        onLoadFailed: root.loaded = true
    }
}
