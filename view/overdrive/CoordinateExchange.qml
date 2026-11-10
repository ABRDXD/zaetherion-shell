import qs.view.cues
import qs.view.ui
import QtQuick

// Coordinate exchange (docs/OVERDRIVE_IDEAS.md #36): for the first part of a room switch the page's rulers are one pair of basis vectors, and they turn a quarter, so the two axes change
// places. It starts and ends on the house angles (−12° and 78°), and the direction follows the way the switch runs through the rooms. The two rooms' numbers ride one axis each, so they cross.
Item {
    id: root
    property real t: 0
    property bool switching: false
    property int fromIndex: 0
    property int toIndex: 0
    // Ends before the dive, so the causal cut has the screen to itself.
    readonly property real raw: switching ? Math.max(0, Math.min(1, (t - 0.04) / 0.52)) : 0
    readonly property real turn: raw * raw * (3 - 2 * raw)
    readonly property real direction: toIndex >= fromIndex ? 1 : -1
    readonly property real angle: -12 + direction * 90 * turn
    readonly property real reach: Math.hypot(width, height)
    function basis(degrees) { const a = degrees * Math.PI / 180; return Qt.point(Math.cos(a), Math.sin(a)); }
    function number(i) { return String(i).padStart(2, "0"); }
    readonly property point u: basis(angle)
    readonly property point v: basis(angle + 90)
    visible: switching && raw < 1
    opacity: Math.min(1, raw / 0.12) * Math.min(1, (1 - raw) / 0.15) * Motion.drive
    Item {
        x: root.width / 2
        y: root.height / 2
        rotation: root.angle
        Repeater {
            model: 25
            Rectangle {
                required property int index
                readonly property int step: index - 12
                x: -root.reach / 2
                y: step * 74
                width: root.reach
                height: step === 0 ? 2 : 1
                color: step === 0 ? Design.accent : Qt.alpha(Design.accent, 0.42)
            }
        }
        Repeater {
            model: 25
            Rectangle {
                required property int index
                readonly property int step: index - 12
                x: step * 74
                y: -root.reach / 2
                width: step === 0 ? 2 : 1
                height: root.reach
                color: step === 0 ? Design.warm : Qt.alpha(Design.warm, 0.42)
            }
        }
    }
    // Each room's number rides its own axis through the centre: the one you leave goes out as the one you chose comes in.
    FText {
        readonly property real along: -root.height * 0.34 * (1 - root.turn) + root.height * 0.34 * root.turn
        x: root.width / 2 + root.u.x * along - width / 2
        y: root.height / 2 + root.u.y * along - height / 2
        text: root.number(root.fromIndex)
        headline: true
        font.pixelSize: Design.display
        font.weight: Font.Black
        color: Design.warm
        opacity: 1 - root.turn
    }
    FText {
        readonly property real along: root.height * 0.34 * (1 - root.turn) - root.height * 0.34 * root.turn
        x: root.width / 2 + root.v.x * along - width / 2
        y: root.height / 2 + root.v.y * along - height / 2
        text: root.number(root.toIndex)
        headline: true
        font.pixelSize: Design.display
        font.weight: Font.Black
        color: Design.accent
        opacity: root.turn
    }
}
