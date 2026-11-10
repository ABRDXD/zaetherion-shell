import qs.view.cues
import QtQuick

// The editorial cut (MONTAGE.md §4): a wedge of ink standing on one edge of a room, its outer edge at 78°,
// carrying the room's name along that edge in large type. The wedge's straight inner edge crops the name
// where the wedge narrows. Where the wedge covers only part of the height, the room's number and line
// sit in the free part of the column. Static: it only moves with the canvas.
Item {
    id: root
    property string text: ""
    property string number: ""
    property string voice: ""
    // The edge the wedge stands on, the share of the height it covers, and which end it starts from.
    property string side: "left"
    property real span: 1
    property string align: "top"
    // Idle on the current room's wedge: a hatch strip running along its inner edge (MONTAGE.md §4.5).
    property bool live: false
    readonly property bool leftSide: side === "left"
    readonly property real bladeHeight: Math.round(height * Math.max(0.3, Math.min(1, span)))
    readonly property real bladeY: align === "top" ? 0 : height - bladeHeight
    readonly property real run: bladeHeight * -Design.shear
    readonly property real pad: 10
    readonly property string label: text.toUpperCase()
    // The name fills the length of the edge, but never more than the wedge is wide.
    readonly property real fit: metrics.advanceWidth > 0 ? 100 * (bladeHeight * 1.02 - 2 * pad) / metrics.advanceWidth : 0
    readonly property int nameSize: Math.max(Design.readout, Math.round(Math.min(width * 0.86, fit)))
    // Where the name is set, for a title drawn over this one (view/shell/LiveTitle, Overdrive's type under load):
    // its origin, angle, the length of edge it may fill, and the ink it is set in. `nameOpacity` hands the name over.
    readonly property real nameX: leftSide ? pad : width - pad
    readonly property real nameY: leftSide ? bladeY + bladeHeight - pad : bladeY + pad
    readonly property real nameRotation: leftSide ? -78 : 102
    readonly property real nameLength: bladeHeight * 1.02 - 2 * pad
    readonly property color textColor: blade.textColor
    property real nameOpacity: 1
    clip: true

    TextMetrics {
        id: metrics
        font.family: Design.sans
        font.pixelSize: 100 // scale: the reference size the fit is measured at
        font.weight: Font.Black
        text: root.label
    }
    Plane {
        id: blade
        y: root.bladeY
        width: root.width
        height: root.bladeHeight
        role: "ink"
        // The outer edge leans; the inner edge, against the room, stays straight.
        slant: root.leftSide ? 1 : 2
    }
    Item {
        id: rail
        x: root.leftSide ? root.width - width - 6 : 6
        y: root.bladeY + 8
        width: 10
        height: root.bladeHeight - 16
        clip: true
        visible: root.live
        Hatch {
            id: railHatch
            width: parent.width
            height: parent.height + cellHeight
            pitch: 5
            color: blade.textColor
            strength: 0.55
            y: -railHatch.cellHeight * railLoop.phase
        }
        IdleLoop { id: railLoop; scope: rail; name: "cut.rail"; enabled: root.live; period: 1200 }
    }
    // Along the outer edge: reading up on the left, down on the right; the glyphs lie inside the wedge.
    FText {
        x: root.nameX
        y: root.nameY
        transformOrigin: Item.TopLeft
        rotation: root.nameRotation
        opacity: root.nameOpacity
        visible: opacity > 0
        text: root.label
        headline: true
        sheared: false
        font.pixelSize: root.nameSize // scale: the name fitted to the wedge
        font.weight: Font.Black
        font.letterSpacing: -1
        lineHeight: 0.8
        color: blade.textColor
    }
    // The free part of the column: the number, then the room's line.
    Column {
        visible: root.bladeHeight < root.height - 60
        x: 8
        y: root.align === "top" ? root.bladeHeight + 14 : 6
        width: root.width - 16
        spacing: 6
        FText {
            text: root.number
            headline: true
            font.pixelSize: Design.figure
            font.weight: Font.Black
            color: Design.accent
        }
        FText {
            width: parent.width
            visible: root.voice !== ""
            text: root.voice
            aside: true
            font.pixelSize: Design.caption
            wrapMode: Text.Wrap
            color: Design.muted
        }
    }
}
