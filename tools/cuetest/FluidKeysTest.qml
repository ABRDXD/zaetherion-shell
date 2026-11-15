import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.view.fluid
import qs.view.ui as UI
import "view/fluid/FluidKeys.js" as Keys_

// Fluid's keyboard behaviour (after Radix / Base UI), offscreen: buttons and action rows take focus from the keyboard
// only, show their ring when focused, ←/→ move along a row skipping hidden and disabled controls, ↑/↓ move along a
// list of action rows, and Enter presses.
Scope {
    id: root
    function check(name, ok, detail) { ok ? console.log("CUE_PASS", name) : console.log("CUE_FAIL", name, JSON.stringify(detail ?? {})); }
    property int pressed: 0
    FloatingWindow {
        implicitWidth: 600; implicitHeight: 300; visible: true; color: "#000000"
        ColumnLayout {
            anchors.fill: parent
            Row {
                id: toolbar
                FluidButton { id: a; text: "Reset" }
                FluidButton { id: hidden; text: "Hidden"; visible: false }
                FluidButton { id: off; text: "Off"; enabled: false }
                FluidButton { id: b; text: "Start"; primary: true; onClicked: root.pressed++ }
            }
            FluidActionRow { id: r1; Layout.fillWidth: true; text: "First"; detail: "→" }
            FluidActionRow { id: r2; Layout.fillWidth: true; text: "Second"; detail: "→" }
        }
    }
    Component.onCompleted: Qt.callLater(() => {
        check("keyboard.only.focus", a.focusPolicy === Qt.TabFocus && r1.focusPolicy === Qt.TabFocus, [a.focusPolicy, r1.focusPolicy]);
        a.forceActiveFocus(Qt.TabFocusReason);
        check("ring.when.focused", a.activeFocus && a.background.border.width === 2, a.background.border.width);
        const next = Keys_.sibling(a, 1);
        check("arrows.skip.hidden.and.disabled", next === b, next?.text);
        check("arrows.stop.at.the.end", Keys_.sibling(b, 1) === null && Keys_.sibling(a, -1) === null, {});
        r1.forceActiveFocus(Qt.TabFocusReason);
        check("down.moves.along.a.list", Keys_.along(r1, true) === r2 && Keys_.along(r2, false) === r1, {});
        b.click();
        check("enter.presses", root.pressed === 1, root.pressed);
        console.log("CUE_DONE");
        Qt.quit();
    })
}
