import qs.view.ui
import QtQuick
import "Attention.js" as A

// Inbox's attention band, in place of its rule (docs/OVERDRIVE.md §23): attention shown as structure, from sources,
// counts and times only, never a message. Static in Silent and Overdrive alike: it changes when a notification arrives
// or is read, and its clock moves once a minute.
// - Source eclipse (#33): each source with unread items is a sheared slab across the attention axis, as wide as its
//   unread count calls for, the longest-ignored first, each partly eclipsing the next. Names only on hover.
// - Arrival cadence (#34): the last 24 hours as a score, a tick per arrival (taller when critical), in the accent while
//   unread. Bursts are tight barcodes; quiet hours are rests.
// - Silence debt (#35): unread items weigh by how long they've been left (a whole one after a day); the debt hangs
//   from the band's right edge as an overhang. Reading it cuts the overhang away, with a sound of paper.
Item {
    id: root
    property var items: []
    property bool active: false
    implicitHeight: 40
    readonly property double now: { Clock.minuteStr; return Date.now(); }
    readonly property real debt: A.debt(items, now)
    readonly property real hang: A.overhang(debt)
    readonly property real span: Math.max(40, width - hang - 10)
    readonly property var slabs: A.eclipse(A.sources(items), span)
    readonly property var ticks: A.cadence(items, now)
    property real lastDebt: 0
    onDebtChanged: {
        if (active && debt < lastDebt - 0.5)
            Feedback.play("foley.paper");
        lastDebt = debt;
    }
    property string hovered: ""

    // The attention axis and the sources eclipsing it.
    Rectangle { y: 9; width: root.span; height: 1; color: Design.line }
    Repeater {
        model: root.slabs
        Plane {
            required property var modelData
            required property int index
            x: modelData.x
            y: 2
            width: modelData.w
            height: 15
            slant: 3
            role: index % 2 ? "signal" : "ink"
            opacity: root.hovered === modelData.app ? 0.75 : 0.32
            HoverHandler { onHoveredChanged: root.hovered = hovered ? modelData.app : root.hovered === modelData.app ? "" : root.hovered }
        }
    }
    FText {
        visible: root.hovered !== ""
        x: Math.min(root.span - implicitWidth, (root.slabs.find(s => s.app === root.hovered)?.x ?? 0))
        y: -12
        text: root.hovered.toUpperCase() + " · " + (root.slabs.find(s => s.app === root.hovered)?.unread ?? 0) + " UNREAD"
        technical: true
        font.pixelSize: 9   // scale: the band's figures
        color: Design.muted
    }
    // The score: a day of arrivals.
    Rectangle { y: 33; width: root.span; height: 1; color: Design.line }
    Repeater {
        model: root.ticks
        Rectangle {
            required property var modelData
            x: modelData.x * root.span - 0.5
            y: 33 - height
            width: 1
            height: modelData.urgent ? 11 : 6
            color: modelData.unread ? Design.accent : Design.faint
        }
    }
    FText { x: 0; y: 34; text: "24 H"; technical: true; font.pixelSize: 9; color: Design.faint }   // scale: the band's figures
    FText { x: root.span - implicitWidth; y: 34; text: "NOW"; technical: true; font.pixelSize: 9; color: Design.faint }   // scale: the band's figures
    // The debt's overhang at the right edge.
    Plane {
        visible: root.hang > 0
        x: root.width - root.hang
        y: 0
        width: root.hang
        height: root.height
        slant: 1
        role: "ink"
        opacity: 0.22
    }
    FText {
        visible: root.hang > 0
        x: root.width - implicitWidth - 2
        y: -implicitHeight - 1
        text: "DEBT " + root.debt.toFixed(1)
        technical: true
        font.pixelSize: 9   // scale: the band's figures
        color: Design.muted
    }
}
