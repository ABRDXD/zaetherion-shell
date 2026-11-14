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
    property int rows: 6
    signal close()

    property var results: []
    property int selected: 0
    property string refusal: ""
    property int asked: 0
    readonly property alias text: input.text

    implicitWidth: Layout.contentWidth
    implicitHeight: Layout.inputHeight + Layout.notice + Layout.gap + rows * Layout.rowHeight + Layout.gap

    function query(): void {
        if (!core) return;
        const seq = ++asked;
        core.request("launcher.query", { text: input.text, limit: rows }, (ok, reply) => {
            if (seq !== asked) return;
            results = ok ? reply.rows : [];
            selected = Math.min(selected, Math.max(0, results.length - 1));
        });
    }
    function move(by: int): void {
        if (results.length > 0)
            selected = (selected + by + results.length) % results.length;
    }
    function launch(index: int): void {
        const row = results[index];
        if (!row || !core) return;
        core.request("launcher.launch", { id: row.id }, (ok, reply) => {
            if (!ok) {
                refusal = reply?.code === "blocked" ? reply.message : "> " + (reply?.message ?? "CANNOT START").toUpperCase();
                Feedback.play("ui.error");
                return;
            }
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
                root.selected = 0;
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

    Column {
        y: Layout.inputHeight + Layout.notice + Layout.gap
        width: parent.width
        Repeater {
            model: root.results
            delegate: LauncherRow {
                required property var modelData
                required property int index
                width: parent.width
                height: Layout.rowHeight
                row: modelData
                selected: index === root.selected
                onPointed: root.selected = index
                onChosen: root.launch(index)
            }
        }
    }
    FText {
        y: Layout.inputHeight + Layout.notice + Layout.gap
        visible: root.results.length === 0 && input.text !== ""
        technical: true
        text: "> NO MATCH"
        color: Design.faint
        font.pixelSize: Design.caption
    }
}
