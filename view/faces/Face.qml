import qs.view.ui
import QtQuick
import QtQuick.Layouts

// A planet's face (docs/ORBIT.md §5): one live fact about a room. The host (OrbitSystem) owns the
// frame, the number and the name; a face draws only the fact, laid out from the size it is given:
// - tier 0, a tile's corner (about 45–95 × 28–55): the figure alone;
// - tier 1, a round planet or a mid-sized slot: the figure and a note under it;
// - tier 2, the readout (about 236 × 110): the figure, the note and a detail line.
// An alarm (late, done, recording, unread) is the note inverted: the plane's text colour as a tag, the
// plane's colour as its text, so it reads on paper, ink and signal planes without a hue. At tier 0, with
// no note, it is a solid node beside the figure (the sheet's ruling-line node).
// Nothing in a face animates. It changes only when its fact does, and does no work while not live.
Item {
    id: root
    // The host clears this while the orbit is hidden: no timers, no leases.
    property bool live: true
    // The plane under the face: its text colour and its fill (`tone: plane.textColor; ground: plane.fillColor`).
    property color tone: Design.ink
    property color ground: Design.surface

    // What a face sets.
    property string figure: ""
    // The fact in words for a tile's corner (tier 0), where only one line fits: "3 LATE" rather than the
    // bare count. Empty: the figure.
    property string brief: ""
    property string note: ""
    property string detail: ""
    property bool alarm: false
    property int figureWeight: Font.Black
    // Replaces the figure with an item (the Devices glyphs). It reads `tier` and `figureHeight`.
    property Component figureItem: null

    readonly property int tier: height < 56 ? 0 : width >= 200 && height >= 96 ? 2 : 1
    readonly property int labelSize: Math.max(8, Math.min(Design.control, Math.round(height * (tier === 2 ? 0.12 : 0.14))))
    // The figure's line, and the font size that fills it (a line is about 1.2 × the font size).
    readonly property int figureHeight: tier === 0 ? height
        : Math.max(16, Math.min(Design.display, Math.round(height - (labelSize * 1.3 + 3) * tier - 2)))
    readonly property int figureSize: Math.round(figureHeight / 1.22)
    readonly property int nodeSize: Math.max(4, Math.round(figureHeight * 0.18))
    readonly property bool node: alarm && tier === 0
    implicitWidth: 180
    implicitHeight: 180

    // One centred line: shrinks to the face's width instead of eliding, never below 8 px.
    component Line: FText {
        property bool mono: false
        headline: !mono
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        fontSizeMode: Text.HorizontalFit
        minimumPixelSize: 8
    }
    // A line that inverts into a tag when it carries the alarm.
    component Tag: Item {
        id: tag
        property alias text: label.text
        property alias font: label.font
        property bool mono: true
        property bool inverted: false
        property bool node: false
        property real dim: 0.78
        readonly property int pad: inverted ? Math.max(3, Math.round(label.font.pixelSize * 0.3)) : 0
        readonly property int nodeRoom: node ? root.nodeSize + 3 : 0
        implicitWidth: Math.min(root.width, label.implicitWidth + pad * 2 + nodeRoom * 2)
        implicitHeight: label.implicitHeight
        clip: true
        Rectangle {
            visible: tag.inverted
            anchors.fill: parent
            color: root.tone
        }
        Line {
            id: label
            anchors.centerIn: parent
            width: Math.min(implicitWidth, root.width - tag.pad * 2 - tag.nodeRoom * 2)
            height: parent.height
            mono: tag.mono
            font.weight: tag.inverted ? Font.Bold : Font.Normal
            color: tag.inverted ? root.ground : root.tone
            opacity: tag.inverted ? 1 : tag.dim
        }
        Rectangle {
            visible: tag.node
            x: label.x + label.width + 3
            y: Math.round(tag.height * 0.18)
            width: root.nodeSize
            height: width
            color: root.tone
        }
    }

    ColumnLayout {
        anchors.centerIn: parent
        width: parent.width
        spacing: 0
        Loader {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredHeight: root.figureHeight
            Layout.maximumWidth: root.width
            active: root.figureItem !== null
            visible: active
            sourceComponent: root.figureItem
        }
        Tag {
            visible: root.figureItem === null
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredHeight: root.figureHeight
            text: root.tier === 0 && root.brief !== "" ? root.brief : root.figure
            mono: false
            // At tier 0 the figure is all there is, so the alarm is a node beside it.
            node: root.node
            dim: 1
            font.pixelSize: root.figureSize
            font.weight: root.figureWeight
        }
        Tag {
            visible: root.tier >= 1 && text.length > 0
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 2
            text: root.note
            inverted: root.alarm
            font.pixelSize: root.labelSize
        }
        Tag {
            visible: root.tier === 2 && text.length > 0
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 3
            text: root.detail
            dim: 0.6
            font.pixelSize: Math.max(8, root.labelSize - 1) // scale: one below the note, never under 8 px
        }
    }
}
