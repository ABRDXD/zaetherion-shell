import QtQuick
import Quickshell
import qs.core.client
import qs.view.contract
import qs.view.cues
import qs.view.ui
import "LauncherLayout.js" as Layout

// The launcher grown out of the island (S6, Z26, Z29, Z75): a line to type in and the core's ranked rows under it.
// The core matches and ranks (`launcher.query`), allows and records a launch (`launcher.launch`); the adapter starts
// the app (`apps.launch`). Every key asks the core; a reply that is no longer the latest is dropped.
FocusScope {
    id: root
    required property CoreClient core
    required property AppsDomain apps
    property ClipboardDomain clipboard: null
    property int rows: 6
    signal close()

    property var results: []
    // The selection, unwrapped: every step counts, so the orbit swings the short way past the wrap (Z196).
    property int turn: 0
    readonly property int selected: results.length ? ((turn % results.length) + results.length) % results.length : 0
    property string refusal: ""
    property int asked: 0
    readonly property alias text: input.text

    implicitWidth: Layout.contentWidth
    implicitHeight: Layout.inputHeight + Layout.notice + Layout.chartHeight

    function query(): void {
        if (!core) return;
        const seq = ++asked;
        core.request("launcher.query", { text: input.text, limit: rows }, (ok, reply) => {
            if (seq !== asked) return;
            turn = 0;
            results = ok ? reply.rows : [];
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
    function act(row): void {
        const text = input.text;
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
    Component.onDestruction: if (probe && live) console.log("FART_LAUNCHER", "closed", Date.now())
    Component.onCompleted: {
        if (!live) return;
        if (probe) {
            console.log("FART_LAUNCHER", "open", Date.now());
            console.log("FART_CMDFOCUS", Date.now(), "window", root.Window.window?.active ?? false);
            console.log("FART_CMDFOCUS", Date.now(), "input", input.activeFocus);
        }
        input.forceActiveFocus();
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
            text: ">"
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
                else if (event.key === Qt.Key_Escape) root.close();
                else return;
                event.accepted = true;
            }
        }
        FText {
            anchors.left: input.left
            anchors.verticalCenter: parent.verticalCenter
            visible: input.text === ""
            text: "APPS"
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
