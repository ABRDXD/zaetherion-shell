import qs.view.cues
import qs.view.ui
import QtQuick

// What a room switch does at its end, in Overdrive (docs/OVERDRIVE_IDEAS.md #38, #39), over the field.
// Aberration: on a long jump the destination's name appears as two images, offset along 78°, that converge as the
// camera dives (double imaging, the lens's other effect). Causal cut: the last stretch of the dive is covered by two
// sheared panes that part from where the switch was asked for, the far side first, as a splice.
Item {
    id: root
    // How far through the flight (0..1), the moment the dive begins, and whether this flight is a switch.
    property real t: 0
    property real diveAt: 0.6
    property bool switching: false
    // The hop's share of the longest flight (0.55..1): a long jump is above 0.8.
    property real hop: 0.55
    property string name: ""
    // Where the switch was asked for, in this item's coordinates.
    property real causeX: width / 2
    clip: true
    readonly property real dive: switching ? Math.max(0, Math.min(1, (t - diveAt) / (1 - diveAt))) : 0
    function span(a, b) { return Math.max(0, Math.min(1, (dive - a) / (b - a))); }
    readonly property real run: height * -Design.shear
    // Aberration: two images of the name, converging.
    Repeater {
        model: root.switching && root.hop > 0.8 ? [1, -1] : []
        FText {
            required property int modelData
            readonly property real gap: 90 * (1 - root.span(0.05, 0.7))
            anchors.centerIn: parent
            anchors.horizontalCenterOffset: gap * 0.2079 * modelData
            anchors.verticalCenterOffset: -gap * 0.9781 * modelData
            text: root.name.toUpperCase()
            headline: true
            font.pixelSize: Design.display
            font.weight: Font.Black
            color: modelData > 0 ? Design.accent : Design.warm
            opacity: Math.min(1, root.span(0, 0.25)) * (1 - root.span(0.62, 0.8)) * 0.8
        }
    }
    // The cut: the pane on the far side of the cause parts first, then the near one, from the cause outwards.
    readonly property bool causeLeft: causeX < width / 2
    readonly property real farOpen: span(0.55, 0.82)
    readonly property real nearOpen: span(0.72, 1)
    readonly property real leftOpen: causeLeft ? nearOpen : farOpen
    readonly property real rightOpen: causeLeft ? farOpen : nearOpen
    readonly property bool cutting: switching && dive > 0.55 && dive < 1
    onCuttingChanged: if (cutting) Feedback.play("foley.splice")
    Plane {
        visible: root.cutting
        x: -root.run - root.width * root.leftOpen
        width: root.causeX + root.run
        height: root.height
        role: "ink"
        slant: 2
    }
    Plane {
        visible: root.cutting
        x: root.causeX + root.width * root.rightOpen
        width: root.width - root.causeX + root.run
        height: root.height
        role: "ink"
        slant: 1
    }
}
