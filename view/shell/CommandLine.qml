import QtQuick
import qs.core.client
import qs.view.cues
import qs.view.ui
import "IntentGate.js" as Gate

// The command line (DAILY_DRIVER §4, decisions §11). The core owns the grammar, matching and
// history (`cmd.run`, `cmd.complete`, `cmd.history`); this is only the input, the hint and the log.
// Enter runs at once and never waits for a reply or for motion (CUES rule 1): each line gets its
// own log entry showing `…` until its reply lands, so five Enters make five entries, in order.
FocusScope {
    id: root
    required property CoreClient core
    // The panel is open. Folding clears the log, the hint and the input.
    property bool panelOpen: false
    readonly property alias text: input.text
    readonly property bool inputFocused: input.activeFocus
    // Q7: Super+` on a focused, empty command line folds the panel (the core decides from this).
    readonly property bool idle: input.activeFocus && input.text === ""
    readonly property int maxLog: 3
    // {key, line, result, tone}, newest last; tone is pending, ok, info or error. A ListModel, so
    // settling one entry does not rebuild (and re-fade) the others.
    readonly property ListModel log: ListModel {}
    // The live hint for the current text: cmd.complete's reply, or null.
    property var hint: null
    property var history: []
    // -1 while editing; otherwise the index into `matches` being shown.
    property int browse: -1
    property string draft: ""
    property var matches: []
    property int seq: 0
    property int hintSeq: 0
    property double lastKeyCue: 0
    // The text the live hint answered, so a stale hint never decides a gate.
    property string hintFor: ""
    // The intent gate (atlas #62, view/shell/IntentGate.js), Overdrive only: a line that cuts something off waits here
    // as two planes out of register until the room's number is typed. { line, verb, room, what, seq, typed } or null.
    property var gate: null
    // The Shell's room order, for the number that registers a gate: id → index (Home 0).
    property var roomIndexOf: id => 0
    readonly property int gateNotches: gate ? Gate.notches(gate.seq, gate.typed) : 0
    readonly property bool gateRegistered: gate !== null && Gate.registered(gate.seq, gate.typed)
    signal escapeEmpty()
    signal tabOut()

    implicitHeight: 32

    function focusInput() {
        input.forceActiveFocus();
    }
    // Typing anywhere in the panel lands here (DAILY_DRIVER §4.1).
    function typeIn(characters) {
        input.forceActiveFocus();
        input.insert(input.cursorPosition, characters);
        edited();
    }
    function push(entry) {
        log.append(entry);
        while (log.count > maxLog)
            log.remove(0);
    }
    function find(key) {
        for (let i = 0; i < log.count; i++)
            if (log.get(i).key === key)
                return i;
        return -1;
    }
    // A reply for an entry that already scrolled out is dropped.
    function settle(key, result, tone) {
        const i = find(key);
        if (i < 0)
            return;
        log.setProperty(i, "result", String(result));
        log.setProperty(i, "tone", tone);
    }
    function drop(key) {
        const i = find(key);
        if (i >= 0)
            log.remove(i);
    }
    // The log as plain data, for tests and diagnostics.
    function lines() {
        const out = [];
        for (let i = 0; i < log.count; i++)
            out.push(log.get(i).line + " → " + log.get(i).result);
        return out;
    }
    function run() {
        const line = input.text.trim();
        if (line === "")
            return;
        if (gate !== null) {
            if (gateRegistered) {
                gate = null;
                send(line);
            }
            return;
        }
        const resolved = hintFor === input.text ? (hint?.verb ?? "") : "";
        const g = Motion.driving ? Gate.gate(line, resolved) : null;
        if (g !== null) {
            gate = Object.assign(g, { line: line, seq: Gate.sequence(roomIndexOf(g.room)), typed: 0 });
            hint = null;
            return;
        }
        send(line);
    }
    // A key while gated: a digit against the room's number; anything else typed throws the planes apart.
    function gateKey(text) {
        if (gate === null || text === "")
            return;
        const typed = Gate.step(gate.seq, gate.typed, text);
        gate = Object.assign({}, gate, { typed: typed });
        Feedback.play(typed > 0 ? "ui.key" : "ui.error");
    }
    function ungate() {
        gate = null;
    }
    function send(line) {
        const entry = { key: ++seq, line: line, result: "…", tone: "pending" };
        push(entry);
        input.clear();
        browse = -1;
        hint = null;
        core.request("cmd.run", { line: line }, (ok, reply) => {
            if (!ok)
                settle(entry.key, reply?.message ?? "the core did not answer", "error");
            else if (reply.fallthrough)
                drop(entry.key); // the panel folded for the host launcher
            else {
                settle(entry.key, reply.line, reply.tone ?? (reply.ok ? "ok" : "error"));
                // Ambiguous: Enter completes to the candidates' common prefix, if nothing was typed since.
                if (reply.code === "ambiguous" && input.text === "" && reply.complete) {
                    const first = line.split(/\s+/)[0];
                    input.text = reply.complete.length > first.length ? reply.complete + line.slice(first.length) : line;
                    edited();
                }
            }
            loadHistory();
        });
    }
    function loadHistory() {
        core.request("cmd.history", { limit: 100 }, (ok, reply) => { if (ok) root.history = reply.lines ?? []; });
    }
    // Up and Down browse the history, prefix-filtered by what was typed when browsing began.
    function older() {
        if (browse < 0) {
            draft = input.text;
            matches = history.filter(l => l.startsWith(draft) && l !== draft);
            if (matches.length === 0)
                return;
            browse = matches.length;
        }
        if (browse === 0)
            return;
        browse--;
        input.text = matches[browse];
    }
    function newer() {
        if (browse < 0)
            return;
        browse++;
        if (browse >= matches.length) {
            browse = -1;
            input.text = draft;
        } else {
            input.text = matches[browse];
        }
    }
    function complete() {
        const first = input.text.split(/\s+/)[0];
        const target = hint?.complete ?? "";
        if (target.length > first.length && target.startsWith(first.toLowerCase())) {
            input.text = target + input.text.slice(first.length);
            edited();
        } else {
            tabOut();
        }
    }
    function cancel() {
        if (input.text !== "") {
            input.clear();
            browse = -1;
            hint = null;
        } else {
            escapeEmpty();
        }
    }
    // A user edit: the hint follows it; a stale reply is ignored.
    function edited() {
        browse = -1;
        const text = input.text;
        const token = ++hintSeq;
        if (text.trim() === "") {
            hint = null;
            return;
        }
        core.request("cmd.complete", { text: text }, (ok, reply) => {
            if (token === root.hintSeq) {
                root.hint = ok ? reply : null;
                root.hintFor = text;
            }
        });
    }
    // On fold. Focus goes too: a focused TextInput keeps its cursor-blink timer running in a hidden
    // window, which woke a kept Shell (Q2) about twice a second while closed.
    function reset() {
        gate = null;
        input.focus = false;
        input.clear();
        log.clear();
        hint = null;
        browse = -1;
    }
    onPanelOpenChanged: panelOpen ? loadHistory() : reset()
    // A release puts the line back as typed: nothing gated runs.
    Connections {
        target: Motion
        function onDrivingChanged() { if (!Motion.driving) root.gate = null; }
    }

    FFrame {
        anchors.fill: parent
        fillColor: Design.surface
        lineColor: input.activeFocus ? Design.accent : Design.line
    }
    FText {
        id: prompt
        anchors.left: parent.left
        anchors.leftMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        text: ">"
        technical: true
        color: input.activeFocus ? Design.accent : Design.faint
    }
    TextInput {
        id: input
        anchors.left: prompt.right
        anchors.leftMargin: 8
        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        focus: true
        clip: true
        color: Design.ink
        selectionColor: Design.accent
        selectedTextColor: Design.background
        font.family: Design.mono
        font.pixelSize: Design.control
        maximumLength: 1000
        // While gated, the planes stand in for the line.
        opacity: root.gate === null ? 1 : 0
        Accessible.name: root.gate === null ? "Command line" : "Command line, waiting: type " + root.gate.seq + " to register, Escape to cancel"
        onTextEdited: {
            root.edited();
            const now = Date.now();
            if (now - root.lastKeyCue >= 40) {
                root.lastKeyCue = now;
                Feedback.play("ui.key");
            }
        }
        Keys.onPressed: event => {
            if (root.gate !== null) {
                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) root.run();
                else if (event.key === Qt.Key_Escape) root.ungate();
                else root.gateKey(event.text);
                event.accepted = true;
                return;
            }
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) root.run();
            else if (event.key === Qt.Key_Escape) root.cancel();
            else if (event.key === Qt.Key_Up) root.older();
            else if (event.key === Qt.Key_Down) root.newer();
            else if (event.key === Qt.Key_Tab) root.complete();
            else return;
            event.accepted = true;
        }
        FText {
            anchors.fill: parent
            visible: input.text === ""
            verticalAlignment: Text.AlignVCenter
            text: "type a verb · ? lists them"
            aside: true
            technical: true
            color: Design.faint
        }
    }
    // The gate's two planes (atlas #62): the line twice, in the accent and the danger tone, apart along the house angle by
    // a notch per digit owed. Registered, they print as one line in ink between two registration marks.
    Item {
        id: planes
        anchors.fill: input
        visible: root.gate !== null
        // Glides to a notch per digit owed (no Behavior outside view/cues: an animation restarted on each change).
        property real apart: 0
        readonly property real target: root.gateNotches * 5
        onTargetChanged: { gap.to = target; gap.restart(); }
        NumberAnimation { id: gap; target: planes; property: "apart"; duration: Motion.scaled(160); easing.type: Motion.standard }
        Repeater {
            model: 2
            FText {
                required property int index
                readonly property real sign: index === 0 ? -1 : 1
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: sign * 0.9781 * planes.apart
                x: -sign * 0.2079 * planes.apart
                text: root.gate?.line ?? ""
                technical: true
                font.pixelSize: Design.control
                font.capitalization: Font.MixedCase
                color: root.gateRegistered ? Design.ink : Qt.alpha(index === 0 ? Design.accent : Design.danger, 0.85)
                opacity: root.gateRegistered && index === 1 ? 0 : 1
            }
        }
        // Registration marks at either end once the planes agree.
        Repeater {
            model: root.gateRegistered ? 2 : 0
            Item {
                required property int index
                x: index === 0 ? -14 : gateTail.x - 17
                anchors.verticalCenter: parent.verticalCenter
                width: 9
                height: 9
                Rectangle { anchors.centerIn: parent; width: 9; height: 9; radius: 4.5; color: "transparent"; border.width: 1; border.color: Design.accent }
                Rectangle { anchors.centerIn: parent; width: 13; height: 1; color: Design.accent }
                Rectangle { anchors.centerIn: parent; width: 1; height: 13; color: Design.accent }
            }
        }
        // What it waits for, at the right: the room's number, owed digits faint; then what Enter will cut.
        FText {
            id: gateTail
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.StyledText
            readonly property string owed: root.gate ? root.gate.seq.slice(root.gate.typed) : ""
            readonly property string paid: root.gate ? root.gate.seq.slice(0, root.gate.typed) : ""
            text: root.gateRegistered ? "ENTER CUTS " + (root.gate?.what ?? "")
                : "REGISTER <font color=\"" + Design.accent + "\">" + paid + "</font><font color=\"" + Design.faint + "\">" + owed + "</font> · ESC"
            technical: true
            color: root.gateRegistered ? Design.danger : Design.muted
        }
    }
    // The ignite hold's meter is the fuse on the header's rule (view/overdrive/Fuse.qml, docs/OVERDRIVE.md §2).
    // The hint and the log drop below the header over the room, so the layout never shifts.
    Column {
        id: below
        anchors.top: parent.bottom
        anchors.topMargin: 4
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 2
        z: 30
        visible: root.panelOpen && (hintText.visible || root.log.count > 0)
        Rectangle {
            width: parent.width
            height: hintText.visible ? hintText.implicitHeight + 8 : 0
            visible: hintText.visible
            color: Qt.alpha(Design.background, 0.92)
            FText {
                id: hintText
                x: 10
                y: 4
                width: parent.width - 20
                readonly property var candidates: root.hint?.candidates ?? []
                // In Overdrive several candidates fly out as a ray instead (view/overdrive/BallisticHints.qml).
                visible: input.activeFocus && root.hint !== null && (candidates.length > 0 || !!root.hint.usage) && !(Motion.driving && candidates.length > 1)
                text: candidates.length > 1 ? candidates.map(c => c.name).join(" · ") : (root.hint?.usage ?? "")
                technical: true
                aside: true
                font.capitalization: Font.MixedCase
                color: Design.muted
            }
        }
        Repeater {
            model: root.log
            Rectangle {
                id: entry
                required property int key
                required property string line
                required property string result
                required property string tone
                width: below.width
                height: lineText.implicitHeight + 8
                color: Qt.alpha(Design.background, 0.92)
                opacity: fade.value
                FText {
                    id: lineText
                    x: 10
                    y: 4
                    width: parent.width - 20
                    text: entry.line + "  →  " + entry.result
                    technical: true
                    font.capitalization: Font.MixedCase
                    wrapMode: Text.Wrap
                    elide: Text.ElideNone
                    maximumLineCount: 12
                    color: entry.tone === "error" ? Design.danger : entry.tone === "pending" ? Design.faint : entry.tone === "ok" ? Design.ink : Design.muted
                }
                // A new line fades in with the feedback role; the oldest drops without animation.
                Cue {
                    id: fade
                    on: true
                    scope: entry
                    name: "cmdline.line"
                    enter: Motion.feedback
                    easing: Motion.roles.feedback.easing
                }
                Component.onCompleted: fade.replay()
            }
        }
    }
}
