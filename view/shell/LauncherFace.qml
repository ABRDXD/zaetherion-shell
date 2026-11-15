import QtQuick
import Quickshell
import qs.core.client
import qs.view.contract
import qs.view.cues
import qs.view.ui
import "LauncherLayout.js" as Layout
import "LauncherMerge.js" as Merge

// The launcher grown out of the island (S6, Z26, Z75, Z196): a line to type in and the star chart under it.
// Two sources answer each key (Z197): the host's own launcher engine (`engine`: DMS's apps, files, clipboard,
// settings and plugins) and the core (`launcher.query`: FART verbs, sums and conversions, `>cmd`, `?term`, and its own
// app ranking, which stands in whenever the engine can't answer). LauncherMerge.js decides what shows. The core still
// allows a launch (the Session blocklist, `launcher.launch`); a reply that is no longer the latest is dropped.
FocusScope {
    id: root
    required property CoreClient core
    required property AppsDomain apps
    property ClipboardDomain clipboard: null
    property LauncherDomain engine: null
    property int rows: 6
    signal close()

    property var results: []
    property var coreRows: []
    // The selection, unwrapped: every step counts, so the orbit swings the short way past the wrap (Z196).
    property int turn: 0
    readonly property int selected: results.length ? ((turn % results.length) + results.length) % results.length : 0
    property string refusal: ""
    property int asked: 0
    readonly property alias text: input.text

    implicitWidth: Layout.contentWidth
    implicitHeight: Layout.inputHeight + Layout.notice + Layout.chartHeight

    // A verb's page (after cmdk): its choices as moons; typing filters them, Esc or Backspace on an empty line goes
    // back. null at the root.
    property var page: null
    function pageRows(): var {
        const needle = input.text.trim().toLowerCase();
        return page.options.filter(o => !needle || o.label.toLowerCase().includes(needle)).slice(0, rows)
            .map(o => ({ kind: "moon", id: "moon:" + o.line, name: o.label, line: o.line, description: page.summary, ready: true }));
    }
    function openPage(verb: string): void {
        core.request("launcher.page", { verb: verb }, (ok, reply) => {
            if (!ok || !reply.options.length) return act({ kind: "verb" }, verb);   // nothing to choose: run it bare
            page = reply;
            input.text = "";
            query();
            Feedback.play("ui.click");
        });
    }
    function closePage(): void {
        page = null;
        input.text = "";
        query();
    }
    function query(): void {
        if (!core) return;
        if (page) {
            turn = 0;
            results = pageRows();
            return;
        }
        const seq = ++asked;
        core.request("launcher.query", { text: input.text, limit: rows }, (ok, reply) => {
            if (seq !== asked) return;
            coreRows = ok ? reply.rows : [];
            merge();
        });
        if (engine?.available && input.text.trim() !== "")
            engine.search(input.text);
    }
    // The two sources answer at different times; the selection goes back to the top only when what shows changes,
    // so a late answer that changes nothing never undoes a step already taken.
    function merge(): void {
        if (page) return;   // a page shows its own choices; late answers for the root wait for it to close
        const next = Merge.rows(input.text, coreRows, engine, rows);
        if (Merge.key(next) !== Merge.key(results)) {
            turn = 0;
            results = next;
        }
    }
    Connections {
        target: root.live ? root.engine : null
        function onResultsChanged() { root.merge(); }
        function onAvailableChanged() { if (root.engine.available) root.engine.open(); root.query(); }
    }
    // A result of the host's engine: the core allows it first when it is an app it knows (the Session blocklist),
    // then the engine runs it as its own launcher would.
    function runHost(row): void {
        const go = () => {
            engine.execute(row.key);
            Feedback.play("ui.click");
            root.close();
        };
        if (row.kind !== "app" || !row.id || row.id.startsWith("host:")) return go();
        core.request("launcher.launch", { id: row.id }, (ok, reply) => {
            if (!ok && reply?.code === "blocked") return fail(reply);
            go();  // allowed, or an app only the engine knows
        });
    }
    function move(by: int): void {
        if (results.length > 1)
            turn += by;
    }
    function fail(reply): void {
        refusal = reply?.code === "blocked" ? reply.message : "> " + (reply?.message ?? "CANNOT START").toUpperCase();
        Feedback.play("ui.error");
    }
    // Enter on an inline row (Z195): the core works out what it does again from the text.
    function act(row, line): void {
        const text = line ?? input.text;
        core.request("launcher.act", { kind: row.kind, text: text }, (ok, reply) => {
            if (!ok) return fail(reply);
            if (reply.result && !reply.result.ok) {
                refusal = "> " + String(reply.result.line ?? "").toUpperCase();
                return;  // the core already played the verb's error cue
            }
            if (reply.argv) apps.run(reply.argv);
            else if (reply.copy !== undefined) {
                if (!clipboard) return fail({ message: "no clipboard here" });
                clipboard.copyText(reply.copy);
            }
            if (!reply.result) Feedback.play("ui.click");
            root.close();
        });
    }
    function launch(index: int): void {
        const row = results[index];
        if (!row || !core || row.ready === false) return;
        if (row.source === "host") return runHost(row);
        if (row.kind === "moon") return act({ kind: "verb" }, row.line);
        // A bare verb opens its page of choices; with arguments it runs as typed.
        if (row.kind === "verb" && input.text.trim().split(/\s+/).length === 1) return openPage(input.text.trim());
        if (row.kind && row.kind !== "app") return act(row);
        core.request("launcher.launch", { id: row.id }, (ok, reply) => {
            if (!ok) return fail(reply);
            apps.launch(reply.id, reply.terminal ?? "");
            Feedback.play("ui.click");
            root.close();
        });
    }

    // tools/launcher_keycheck.py, path C (FART_COLD_PROBE=1 only): the markers the panel's command line prints, so
    // one tool reads both: the window taking the keyboard, the line's focus and every change of its text.
    readonly property bool probe: Quickshell.env("FART_COLD_PROBE") === "1"
    Connections {
        target: root.probe && root.live ? input : null
        function onTextChanged() { console.log("FART_CMDTEXT", Date.now(), JSON.stringify(input.text)); }
        function onActiveFocusChanged() { console.log("FART_CMDFOCUS", Date.now(), "input", input.activeFocus); }
    }
    Connections {
        target: root.probe && root.live ? root.Window.window : null
        function onActiveChanged() { console.log("FART_CMDFOCUS", Date.now(), "window", root.Window.window.active); }
    }
    // The island's fading copy of a face that just closed is disabled: it asks nothing and takes no focus.
    readonly property bool live: enabled
    Component.onDestruction: {
        if (probe && live) console.log("FART_LAUNCHER", "closed", Date.now());
        if (live && engine?.available) engine.close();
    }
    Component.onCompleted: {
        if (!live) return;
        if (probe) {
            console.log("FART_LAUNCHER", "open", Date.now());
            console.log("FART_CMDFOCUS", Date.now(), "window", root.Window.window?.active ?? false);
            console.log("FART_CMDFOCUS", Date.now(), "input", input.activeFocus);
        }
        input.forceActiveFocus();
        if (engine?.available) engine.open();
        query();
    }

    Item {
        id: line
        width: parent.width
        height: Layout.inputHeight
        FText {
            id: prompt
            anchors.verticalCenter: parent.verticalCenter
            technical: true
            text: root.page ? "> " + root.page.verb.toUpperCase() + " ›" : ">"
            color: Design.accent
            font.pixelSize: Design.control
        }
        TextInput {
            id: input
            objectName: "launcherInput"
            anchors.left: prompt.right
            anchors.leftMargin: 2 * Design.baseline
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            color: Design.ink
            selectionColor: Design.accent
            selectedTextColor: Design.islandFill
            font.family: Design.sans
            font.pixelSize: Design.readout
            clip: true
            focus: true
            onTextChanged: {
                if (!root.live) return;
                root.refusal = "";
                root.turn = 0;
                root.query();
            }
            Keys.onPressed: event => {
                const ctrl = event.modifiers & Qt.ControlModifier;
                if (event.key === Qt.Key_Down || ctrl && (event.key === Qt.Key_J || event.key === Qt.Key_N)) root.move(1);
                else if (event.key === Qt.Key_Up || ctrl && (event.key === Qt.Key_K || event.key === Qt.Key_P)) root.move(-1);
                else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) root.launch(root.selected);
                else if (event.key === Qt.Key_Escape) root.page ? root.closePage() : root.close();
                else if (event.key === Qt.Key_Backspace && root.page && input.text === "") root.closePage();
                else return;
                event.accepted = true;
            }
        }
        FText {
            anchors.left: input.left
            anchors.verticalCenter: parent.verticalCenter
            visible: input.text === ""
            text: root.page ? "CHOOSE" : "APPS"
            technical: true
            color: Design.faint
            font.pixelSize: Design.control
        }
    }
    FText {
        id: notice
        objectName: "launcherRefusal"
        y: Layout.inputHeight
        height: Layout.notice
        verticalAlignment: Text.AlignVCenter
        technical: true
        text: root.refusal
        color: Design.danger
        font.pixelSize: Design.caption
    }

    LauncherOrbit {
        id: orbit
        objectName: "launcherOrbit"
        y: Layout.inputHeight + Layout.notice
        width: parent.width
        height: Layout.chartHeight
        results: root.results
        turn: root.turn
        onChosen: index => root.launch(index)
        onStep: by => root.move(by)
    }
    FText {
        anchors.horizontalCenter: orbit.horizontalCenter
        y: orbit.y + Layout.orbitY - height / 2
        visible: root.results.length === 0 && input.text !== ""
        technical: true
        text: "> NO BODIES IN RANGE"
        color: Design.faint
        font.pixelSize: Design.caption
    }
}
