import QtQuick
import qs.view.cues

// Rolling digits (after NumberFlow; owner, 15 November 2026: "as much inspo as possible"): a number whose changed
// digits roll into place instead of swapping. Each character has a fixed slot, aligned from the right, so "9:59" to
// "10:00" rolls three digits at once and nothing beside them moves. A digit leaves and its successor arrives in the
// direction the number moves: down when it falls (a countdown), up when it rises (a stopwatch). Separators
// stay still. Motion-gated: reduced motion or a hidden scope swaps at once. Set `text`; style it through `font`/`color`.
Item {
    id: root
    property string text: ""
    property font font
    property color color: "white"
    // +1 rising, −1 falling, 0: decide from the numbers on each change.
    property int trend: 0
    property int duration: 340
    // As FText draws it: letter spacing between slots, and Angular's −12° shear on large numerals.
    property real tracking: font.letterSpacing
    property bool sheared: false
    // Digits share one width (tabular), so a rolling digit never nudges its neighbours; anything else is its own width.
    readonly property real advance: fm.advanceWidth("0")
    function widthOf(c: string): real {
        const shown = font.capitalization === Font.AllUppercase ? c.toUpperCase() : c;
        return (/[0-9]/.test(c) ? advance : fm.advanceWidth(shown)) + tracking;
    }
    transform: Matrix4x4 {
        matrix: Qt.matrix4x4(1, root.sheared ? Design.shear : 0, 0, -(root.sheared ? Design.shear : 0) * root.height / 2,
                             0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
    }
    implicitWidth: text.split("").reduce((w, c) => w + widthOf(c), 0)
    implicitHeight: fm.height
    FontMetrics { id: fm; font: root.font }

    // The slots, rightmost first, so a longer number grows to the left without disturbing the digits it keeps.
    readonly property var chars: text.split("").reverse()
    // The direction of a change, read by each slot as it starts to roll: against the number before this change, which
    // only moves on once every slot has seen the change.
    function numeric(value: string): real { return Number(value.replace(/[^0-9]/g, "")) || 0; }
    property real lastNumber: numeric(text)
    // The step is deferred to a zero-delay timer owned by this readout, so it dies with it: a Qt.callLater closure
    // outlived a torn-down readout and read `root` as null ("Cannot read property 'alive' of null", 17 Nov 2026).
    Timer { id: settle; interval: 0; onTriggered: root.lastNumber = root.numeric(root.text) }
    onTextChanged: settle.restart()
    function directionNow(): int { return trend !== 0 ? trend : numeric(text) < lastNumber ? -1 : 1; }

    Repeater {
        model: root.chars.length
        delegate: Item {
            id: slot
            required property int index
            readonly property string glyph: root.chars[index] ?? ""
            readonly property bool digit: /[0-9]/.test(glyph)
            // From the right edge: every slot to the right of this one, by its own advance.
            x: root.implicitWidth - root.chars.slice(0, index + 1).reduce((w, c) => w + root.widthOf(c), 0)
            width: root.widthOf(glyph)
            height: root.implicitHeight
            clip: true

            property string shown: glyph
            property string leaving: ""
            property real t: 1          // 0 → 1: the leaving glyph goes, the new one arrives
            property int dir: -1        // this roll's direction
            onGlyphChanged: {
                if (!digit || shown === glyph || !Motion.live(root)) { shown = glyph; leaving = ""; t = 1; return; }
                dir = root.directionNow();
                leaving = shown;
                shown = glyph;
                roll.restart();
            }
            NumberAnimation { id: roll; target: slot; property: "t"; from: 0; to: 1; duration: Motion.scaled(root.duration); easing.type: Easing.OutCubic }

            Text {
                text: slot.leaving
                visible: slot.t < 1 && slot.leaving !== ""
                font: root.font
                color: root.color
                y: -slot.dir * slot.height * slot.t * 0.9
                opacity: 1 - slot.t
                renderType: Text.QtRendering
            }
            Text {
                text: slot.shown
                font: root.font
                color: root.color
                y: slot.dir * slot.height * (1 - slot.t) * 0.9
                opacity: slot.t
                renderType: Text.QtRendering
            }
        }
    }
}
