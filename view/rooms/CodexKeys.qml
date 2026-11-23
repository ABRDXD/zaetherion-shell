import qs.view.cues
import qs.view.ui
import qs.view.shell
import QtQuick
import QtQuick.Controls

// Your keys, drawn as the keyboard, leaning on the house angle. A key your compositor binds is lit; the modifiers (click to latch,
// or hold the real ones while the panel has the keyboard) change what the board shows. With none chosen, the list is the whole
// sheet. In Overdrive, changing a modifier sends a wave across the board from that key.
Item {
    id: root
    required property var keybinds
    readonly property var binds: keybinds?.binds ?? []
    readonly property var modifiers: ["SUPER", "SHIFT", "CTRL", "ALT"]
    property var latched: []
    // What's chosen: the latched ones and the ones physically held.
    readonly property var active: modifiers.filter(m => latched.includes(m) || ViewState.heldModifiers.includes(m))
    function canonical(key) {
        const k = String(key).toLowerCase();
        const code = /^code:(\d+)$/.exec(k);
        if (code && Number(code[1]) >= 10 && Number(code[1]) <= 19)
            return String((Number(code[1]) - 9) % 10);
        return ({ "enter": "return", "kp_enter": "return", "prior": "page_up", "next": "page_down", "mouse:272": "lmb", "mouse:273": "rmb" })[k] ?? k;
    }
    function same(a, b) { return a.length === b.length && a.every(m => b.includes(m)); }
    readonly property var shown: binds.filter(b => active.length === 0 || same(b.mods, active))
    readonly property var byKey: {
        const out = {};
        for (const b of shown) {
            const k = canonical(b.key);
            (out[k] = out[k] ?? []).push(b);
        }
        return out;
    }
    readonly property var sections: {
        const order = [], out = {};
        for (const b of shown) {
            if (!out[b.section]) {
                out[b.section] = [];
                order.push(b.section);
            }
            out[b.section].push(b);
        }
        return order.map(s => ({ name: s, binds: out[s] }));
    }
    function combo(b) { return b.mods.concat([keyLabel(b.key)]).join(" + "); }
    function keyLabel(key) {
        const k = canonical(key);
        return ({ lmb: "LEFT CLICK", rmb: "RIGHT CLICK", return: "ENTER", page_up: "PG UP", page_down: "PG DN", super_l: "SUPER", grave: "`", period: ".", comma: ",",
                  minus: "-", equal: "=", slash: "/" })[k] ?? String(key).toUpperCase();
    }
    function toggle(mod) {
        latched = latched.includes(mod) ? latched.filter(m => m !== mod) : latched.concat([mod]);
        Feedback.play("ui.switch");
    }
    property string hoveredKey: ""
    readonly property var hoveredBinds: hoveredKey !== "" ? (byKey[hoveredKey] ?? []) : []
    // The wave: `wave` runs 0 to 1 from the modifier that changed.
    property point waveFrom: Qt.point(0, 0)
    onActiveChanged: if (Motion.driving) waveCue.replay()
    Cue { id: waveCue; name: "codex.wave"; scope: root; enter: Motion.scaled(520); easing: Easing.OutQuad }

    // Rows in key units; each cell is [id, label, width]. A modifier's id is its name.
    readonly property var rows: [
        [["escape", "ESC", 1.5], ...["f1", "f2", "f3", "f4", "f5", "f6", "f7", "f8", "f9", "f10", "f11", "f12"].map(k => [k, k.toUpperCase(), 1]), ["print", "PRT", 1], ["delete", "DEL", 0.5]],
        [["grave", "`", 1], ...["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"].map(k => [k, k, 1]), ["minus", "-", 1], ["equal", "=", 1], ["backspace", "BKSP", 2]],
        [["tab", "TAB", 1.5], ..."qwertyuiop".split("").map(k => [k, k.toUpperCase(), 1]), ["bracketleft", "[", 1], ["bracketright", "]", 1], ["backslash", "\\", 1.5]],
        [["caps_lock", "CAPS", 1.75], ..."asdfghjkl".split("").map(k => [k, k.toUpperCase(), 1]), ["semicolon", ";", 1], ["apostrophe", "'", 1], ["return", "ENTER", 2.25]],
        [["SHIFT", "SHIFT", 2.25], ..."zxcvbnm".split("").map(k => [k, k.toUpperCase(), 1]), ["comma", ",", 1], ["period", ".", 1], ["slash", "/", 1], ["up", "↑", 1], ["SHIFT", "SHIFT", 1.75]],
        [["CTRL", "CTRL", 1.25], ["SUPER", "SUPER", 1.25], ["ALT", "ALT", 1.25], ["space", "SPACE", 4.5], ["ALT", "ALT", 1.25], ["CTRL", "CTRL", 1.25], ["left", "←", 1], ["down", "↓", 1], ["right", "→", 1], ["page_up", "PG", 0.625], ["page_down", "PG", 0.625]]
    ]
    readonly property real unit: Math.min(board.width / 15.2, 56)
    Item {
        id: board
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 34
        anchors.rightMargin: 34
        height: root.unit * 5.6
        transform: Matrix4x4 { matrix: Qt.matrix4x4(1, Design.shear, 0, -Design.shear * board.height / 2, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1) }
        Repeater {
            model: root.rows
            Row {
                id: keyRow
                required property var modelData
                required property int index
                y: index * root.unit * 0.94
                Repeater {
                    model: keyRow.modelData
                    AbstractButton {
                        id: cap
                        required property var modelData
                        readonly property string keyId: modelData[0]
                        readonly property bool modifier: root.modifiers.includes(keyId)
                        readonly property bool on: modifier && root.active.includes(keyId)
                        readonly property var here: modifier ? [] : (root.byKey[keyId] ?? [])
                        readonly property bool bound: here.length > 0
                        width: root.unit * modelData[2]
                        height: root.unit * 0.94
                        hoverEnabled: true
                        activeFocusOnTab: modifier
                        Accessible.name: modelData[1]
                        onHoveredChanged: root.hoveredKey = hovered && !modifier ? keyId : root.hoveredKey === keyId ? "" : root.hoveredKey
                        onClicked: if (modifier) root.toggle(keyId)
                        background: Rectangle {
                            anchors.fill: parent
                            anchors.margins: 2
                            radius: 2
                            color: cap.on ? Design.accent : cap.bound ? Design.ink : Design.surface
                            opacity: cap.bound || cap.on ? 1 : 0.55
                            border.width: cap.hovered || cap.activeFocus ? 2 : 0
                            border.color: Design.warm
                            // The wave passing over this key.
                            y: 2 - 7 * Motion.drive * Math.max(0, 1 - Math.abs(waveCue.value * 16 - cap.mapToItem(board, 0, 0).x / root.unit)) * (waveCue.running ? 1 : 0)
                        }
                        contentItem: FText {
                            text: cap.modelData[1]
                            technical: true
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideRight
                            color: cap.on ? (Design.onSignal ?? Design.background) : cap.bound ? (Design.onInk ?? Design.background) : Design.muted
                        }
                    }
                }
            }
        }
    }
    // What the key under the pointer does, or the state of the board.
    FText {
        id: readout
        anchors.top: board.bottom
        anchors.topMargin: 12
        width: parent.width
        elide: Text.ElideRight
        text: root.hoveredBinds.length > 0 ? root.hoveredBinds.map(b => root.combo(b) + "  —  " + b.description).join("     ")
            : (root.active.length ? root.active.join(" + ") + " + …" : "ALL BINDS") + "  ·  " + root.shown.length + (root.shown.length === 1 ? " BIND" : " BINDS")
        technical: root.hoveredBinds.length === 0
        color: root.hoveredBinds.length > 0 ? Design.ink : Design.muted
    }
    Flickable {
        id: sheet
        anchors.top: readout.bottom
        anchors.topMargin: 10
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        contentHeight: columns.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        Flow {
            id: columns
            width: sheet.width
            spacing: 22
            Repeater {
                model: root.sections
                Column {
                    id: block
                    required property var modelData
                    width: Math.max(300, (sheet.width - 44) / 3)
                    spacing: 3
                    FText {
                        text: block.modelData.name.toUpperCase()
                        headline: true
                        font.pixelSize: Design.readout
                        font.weight: Font.Black
                        bottomPadding: 4
                    }
                    Repeater {
                        model: block.modelData.binds
                        Row {
                            id: line
                            required property var modelData
                            spacing: 10
                            FText {
                                width: 158
                                elide: Text.ElideRight
                                text: root.combo(line.modelData)
                                technical: true
                                color: Design.accent
                            }
                            FText {
                                width: block.width - 168
                                elide: Text.ElideRight
                                text: line.modelData.description
                                color: Design.ink
                            }
                        }
                    }
                }
            }
        }
    }
    FText {
        anchors.centerIn: sheet
        visible: root.keybinds !== null && !root.keybinds.available
        text: "THE HOST REPORTS NO KEYBINDS"
        technical: true
        color: Design.faint
    }
}
