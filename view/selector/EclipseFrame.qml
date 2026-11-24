import QtQuick
import qs.view.ui
import "SelectionGeometry.js" as Geometry

// Eclipse over one screen: the frozen picture is shaded except inside `crop`, whose pixels keep their colour.
// A pale edge, four lime corners and the outside size label mark the crop. With no crop the whole screen is
// shaded; a crop filling the screen shows no frame or label, so nothing covers its contents.
Item {
    id: root
    property var crop: null // {x, y, width, height} in this item's pixels
    property real sourceScale: 1
    property string caption: "" // before the size on the label ("Window" for a window candidate)
    readonly property bool hasCrop: crop !== null && crop.width > 0 && crop.height > 0
    readonly property var bounds: ({ x: 0, y: 0, width: width, height: height })
    readonly property bool marked: hasCrop && !Geometry.fills(crop, bounds)
    readonly property string side: marked ? Geometry.labelSide(crop, bounds, EclipseLook.labelHeight, EclipseLook.labelGap) : "none"
    readonly property alias sizeTab: label
    readonly property real cx: hasCrop ? crop.x : 0
    readonly property real cy: hasCrop ? crop.y : 0
    readonly property real cw: hasCrop ? crop.width : 0
    readonly property real ch: hasCrop ? crop.height : 0

    // The shade: four bands around the crop (one band, the whole screen, without a crop).
    Rectangle { x: 0; y: 0; width: root.width; height: root.hasCrop ? root.cy : root.height; color: EclipseLook.shade; opacity: EclipseLook.shadeOpacity }
    Rectangle { visible: root.hasCrop; x: 0; y: root.cy + root.ch; width: root.width; height: root.height - y; color: EclipseLook.shade; opacity: EclipseLook.shadeOpacity }
    Rectangle { visible: root.hasCrop; x: 0; y: root.cy; width: root.cx; height: root.ch; color: EclipseLook.shade; opacity: EclipseLook.shadeOpacity }
    Rectangle { visible: root.hasCrop; x: root.cx + root.cw; y: root.cy; width: root.width - x; height: root.ch; color: EclipseLook.shade; opacity: EclipseLook.shadeOpacity }

    // The edge sits outside the kept pixels: a dark 3 px line under a pale 1 px one.
    Rectangle {
        visible: root.marked
        x: root.cx - EclipseLook.edgeDarkWidth; y: root.cy - EclipseLook.edgeDarkWidth
        width: root.cw + 2 * EclipseLook.edgeDarkWidth; height: root.ch + 2 * EclipseLook.edgeDarkWidth
        color: "transparent"; border.color: EclipseLook.edgeDark; border.width: EclipseLook.edgeDarkWidth
    }
    Rectangle {
        visible: root.marked
        x: root.cx - EclipseLook.edgeLightWidth; y: root.cy - EclipseLook.edgeLightWidth
        width: root.cw + 2 * EclipseLook.edgeLightWidth; height: root.ch + 2 * EclipseLook.edgeLightWidth
        color: "transparent"; border.color: EclipseLook.edgeLight; border.width: EclipseLook.edgeLightWidth
    }

    // Four lime corners, just outside the edge.
    Repeater {
        model: root.marked ? [[0, 0], [1, 0], [0, 1], [1, 1]] : []
        Item {
            required property var modelData
            readonly property int o: EclipseLook.cornerOffset
            readonly property int l: EclipseLook.cornerLength
            x: modelData[0] ? root.cx + root.cw + o - l : root.cx - o
            y: modelData[1] ? root.cy + root.ch + o - l : root.cy - o
            width: l; height: l
            Rectangle { y: parent.modelData[1] ? parent.l - EclipseLook.cornerWidth : 0; width: parent.l; height: EclipseLook.cornerWidth; color: EclipseLook.lime }
            Rectangle { x: parent.modelData[0] ? parent.l - EclipseLook.cornerWidth : 0; width: EclipseLook.cornerWidth; height: parent.l; color: EclipseLook.lime }
        }
    }

    // The size in source pixels, outside the crop: above it, or below it at the screen's top edge.
    Rectangle {
        id: label
        visible: root.side !== "none"
        width: Math.max(EclipseLook.labelMinWidth, sizeText.implicitWidth + 2 * EclipseLook.labelPadding)
        height: EclipseLook.labelHeight
        x: root.hasCrop ? Geometry.labelX(root.crop, root.bounds, width, EclipseLook.labelInset) : 0
        y: root.side === "below" ? root.cy + root.ch + EclipseLook.labelGap : root.cy - EclipseLook.labelGap - height
        color: EclipseLook.lime
        Text {
            id: sizeText
            x: EclipseLook.labelPadding
            anchors.verticalCenter: parent.verticalCenter
            text: root.hasCrop ? (root.caption ? root.caption + " " : "") + Geometry.sizeText(root.crop, root.sourceScale) : ""
            color: EclipseLook.ink
            font.family: Design.mono
            font.pixelSize: EclipseLook.labelText
        }
    }
}
