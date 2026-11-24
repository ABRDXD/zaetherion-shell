import QtQuick
import qs.view.ui
import "SelectionGeometry.js" as Geometry

// One screen of the live recording picker (Viewfinder, Z222): a transparent layer over the live desktop. A drag
// darkens the surroundings, marks the area with coral corners and its size, and release answers in slurp's format;
// Escape or the right button cancels. The hint moves to the top when the area or its label would meet it, and
// goes when the top is taken too.
FocusScope {
    id: root
    property var screenRect: ({ x: 0, y: 0, width: width, height: height })
    property real sourceScale: 1 // this screen's pixels per logical pixel: the recorder's size
    property bool active: true
    signal picked(string answer)
    signal cancelled()
    signal entered()

    readonly property var bounds: ({ x: 0, y: 0, width: width, height: height })
    readonly property alias dragging: drag.dragging
    readonly property var crop: drag.crop
    readonly property alias hint: hint
    readonly property alias sizeTab: sizeTab
    readonly property string prompt: crop ? "Release to start recording" : "Drag an area to record"
    readonly property real cx: crop ? crop.x : 0
    readonly property real cy: crop ? crop.y : 0
    readonly property real cw: crop ? crop.width : 0
    readonly property real ch: crop ? crop.height : 0

    RegionDrag { id: drag; bounds: root.bounds }

    focus: true
    Keys.onEscapePressed: root.cancelled()

    // The shade, only while there is an area: four bands around it.
    Repeater {
        model: root.crop ? [[0, 0, root.width, root.cy], [0, root.cy + root.ch, root.width, root.height - root.cy - root.ch],
                            [0, root.cy, root.cx, root.ch], [root.cx + root.cw, root.cy, root.width - root.cx - root.cw, root.ch]] : []
        Rectangle {
            required property var modelData
            x: modelData[0]; y: modelData[1]; width: modelData[2]; height: modelData[3]
            color: ViewfinderLook.shade
            opacity: ViewfinderLook.shadeOpacity
        }
    }
    Rectangle {
        visible: !!root.crop
        x: root.cx - ViewfinderLook.ringWidth; y: root.cy - ViewfinderLook.ringWidth
        width: root.cw + 2 * ViewfinderLook.ringWidth; height: root.ch + 2 * ViewfinderLook.ringWidth
        color: "transparent"; border.color: ViewfinderLook.ring; border.width: ViewfinderLook.ringWidth
    }
    Rectangle {
        visible: !!root.crop
        x: root.cx - ViewfinderLook.edgeWidth; y: root.cy - ViewfinderLook.edgeWidth
        width: root.cw + 2 * ViewfinderLook.edgeWidth; height: root.ch + 2 * ViewfinderLook.edgeWidth
        color: "transparent"; border.color: ViewfinderLook.edge; border.width: ViewfinderLook.edgeWidth
    }
    // Coral corners, 4 px, set 4 px outside the area so they frame it.
    Repeater {
        model: root.crop ? [[0, 0], [1, 0], [0, 1], [1, 1]] : []
        Item {
            required property var modelData
            readonly property int t: ViewfinderLook.cornerWidth
            readonly property int l: ViewfinderLook.cornerLength
            x: modelData[0] ? root.cx + root.cw + t - l : root.cx - t
            y: modelData[1] ? root.cy + root.ch + t - l : root.cy - t
            width: l; height: l
            Rectangle { y: parent.modelData[1] ? parent.l - parent.t : 0; width: parent.l; height: parent.t; color: ViewfinderLook.coral }
            Rectangle { x: parent.modelData[0] ? parent.l - parent.t : 0; width: parent.t; height: parent.l; color: ViewfinderLook.coral }
        }
    }
    Rectangle {
        id: sizeTab
        readonly property real above: root.cy - height - ViewfinderLook.sizeMargin
        readonly property real below: root.cy + root.ch + ViewfinderLook.sizeMargin
        visible: !!root.crop && (above >= 0 || below + height <= root.height)
        width: sizeText.implicitWidth + 2 * ViewfinderLook.sizePadX
        height: sizeText.implicitHeight + 2 * ViewfinderLook.sizePadY
        x: Math.max(0, Math.min(root.cx, root.width - width))
        y: above >= 0 ? above : below
        color: ViewfinderLook.coral
        Text {
            id: sizeText
            anchors.centerIn: parent
            text: root.crop ? Geometry.sizeText(root.crop, root.sourceScale) : ""
            color: ViewfinderLook.ink
            font.family: Design.mono
            font.pixelSize: 13
            font.bold: true
        }
    }
    Rectangle {
        id: hint
        readonly property bool compact: root.width <= 540
        readonly property real margin: compact ? 6 : ViewfinderLook.hintMargin
        readonly property var atBottom: ({ x: (root.width - width) / 2, y: root.height - margin - height, width: width, height: height })
        readonly property var atTop: ({ x: atBottom.x, y: margin, width: width, height: height })
        function meets(r) {
            if (!root.crop)
                return false;
            const label = { x: sizeTab.x, y: sizeTab.y, width: sizeTab.width, height: sizeTab.height };
            return Geometry.intersects(r, root.crop) || (sizeTab.visible && Geometry.intersects(r, label));
        }
        readonly property string place: !meets(atBottom) ? "bottom" : !meets(atTop) ? "top" : "none"
        visible: root.active && place !== "none"
        x: atBottom.x
        y: place === "top" ? atTop.y : atBottom.y
        width: compact ? root.width - 2 * margin : hintRow.implicitWidth + 2 * ViewfinderLook.hintPadX
        height: hintRow.implicitHeight + 2 * (compact ? 8 : ViewfinderLook.hintPadY)
        color: ViewfinderLook.hint
        Row {
            id: hintRow
            anchors.centerIn: parent
            spacing: hint.compact ? 6 : ViewfinderLook.hintGap
            Text {
                anchors.verticalCenter: parent.verticalCenter
                id: tag
                text: "RECORD AREA"; color: ViewfinderLook.coral; font.bold: true
                font.family: Design.mono; font.pixelSize: hint.compact ? 10 : 11; font.letterSpacing: ViewfinderLook.tagSpacing
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: hint.compact ? Math.min(implicitWidth, Math.max(1, hint.width - 16 - tag.width - escapeLabel.width - 2 * hintRow.spacing)) : implicitWidth
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
                text: root.prompt; color: ViewfinderLook.paper; font.weight: Font.Medium
                font.family: Design.sans; font.pixelSize: hint.compact ? 15 : 20
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                id: escapeLabel
                text: "Esc · Cancel"; color: ViewfinderLook.hintSmall
                font.family: Design.mono; font.pixelSize: hint.compact ? 10 : 11
            }
        }
    }

    // The pointer's moments, called by the mouse area below (and by tests/test_selector.py's harness).
    function press(x, y, button) {
        if (button === Qt.RightButton)
            return cancelled();
        drag.press(x, y);
    }
    function move(x, y) {
        drag.move(x, y);
    }
    function release(x, y, button) {
        if (button !== Qt.LeftButton)
            return;
        drag.move(x, y);
        const done = drag.release();
        if (done)
            picked(Geometry.answer(done, screenRect));
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        hoverEnabled: true
        cursorShape: Qt.CrossCursor
        onEntered: root.entered()
        onPressed: mouse => root.press(mouse.x, mouse.y, mouse.button)
        onPositionChanged: mouse => root.move(mouse.x, mouse.y)
        onReleased: mouse => root.release(mouse.x, mouse.y, mouse.button)
    }
}
