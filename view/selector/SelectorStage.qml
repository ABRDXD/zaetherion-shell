import QtQuick
import "SelectionGeometry.js" as Geometry

// One screen of the frozen selector: its part of the frozen grab under Eclipse. Region mode drags a crop;
// window mode lights the window under the pointer and a click takes it. Release or click answers in slurp's
// format, in layout coordinates; Escape or the right button cancels.
FocusScope {
    id: root
    property string frozen: "" // the grab's file
    property var origin: ({ x: 0, y: 0 }) // the layout's top-left, where the grab starts
    property real sourceScale: 1 // the grab's pixels per logical pixel
    property var screenRect: ({ x: 0, y: 0, width: width, height: height }) // this screen in the layout
    property string mode: "region" // "region" or "window"
    property var windows: [] // layout boxes {x, y, width, height}, window mode only
    signal picked(string answer)
    signal cancelled()

    readonly property var bounds: ({ x: 0, y: 0, width: width, height: height })
    readonly property var boxes: mode === "window" ? Geometry.boxesOn(windows, screenRect) : []
    property bool dragging: false
    property real anchorX: 0
    property real anchorY: 0
    property var crop: null
    readonly property alias frame: frame
    readonly property alias footer: footer
    readonly property string prompt: mode === "window" ? (crop ? "Click to select" : "Point at a window")
        : dragging ? "Release to select" : "Drag to select"

    function hover(x, y) {
        const i = Geometry.boxAt(boxes, x, y);
        crop = i >= 0 ? boxes[i] : null;
    }

    focus: true
    Keys.onEscapePressed: root.cancelled()
    Keys.onReturnPressed: if (root.mode === "window" && root.crop) root.picked(Geometry.answer(root.crop, root.screenRect))

    Image {
        anchors.fill: parent
        source: root.frozen ? "file://" + root.frozen : ""
        sourceClipRect: {
            const r = Geometry.sourceRect(root.screenRect, root.origin, root.sourceScale);
            return Qt.rect(r.x, r.y, r.width, r.height);
        }
        cache: false
        smooth: true
    }
    EclipseFrame {
        id: frame
        anchors.fill: parent
        crop: root.crop
        sourceScale: root.sourceScale
    }
    SelectorFooter {
        id: footer
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        prompt: root.prompt
        // Steps aside when the crop reaches it, so the crop's pixels are never covered.
        visible: !(root.crop && Geometry.intersects(root.crop, { x: 0, y: y, width: width, height: height }))
    }
    // The pointer's three moments, called by the mouse area below (and by tests/test_selector.py's harness).
    function press(x, y, button) {
        if (button === Qt.RightButton)
            return cancelled();
        if (mode !== "region")
            return;
        anchorX = x;
        anchorY = y;
        crop = null;
        dragging = true;
    }
    function move(x, y) {
        if (mode === "window")
            hover(x, y);
        else if (dragging && Geometry.isDrag(anchorX, anchorY, x, y))
            crop = Geometry.span(anchorX, anchorY, x, y, bounds);
    }
    function release(x, y, button) {
        if (button !== Qt.LeftButton)
            return;
        if (mode === "window") {
            hover(x, y);
            if (crop)
                picked(Geometry.answer(crop, screenRect));
            return;
        }
        dragging = false;
        // A click is not a crop: the selector stays open for a real drag.
        if (crop && crop.width > 0 && crop.height > 0)
            picked(Geometry.answer(crop, screenRect));
        else
            crop = null;
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        hoverEnabled: true
        cursorShape: Qt.CrossCursor
        onPressed: mouse => root.press(mouse.x, mouse.y, mouse.button)
        onPositionChanged: mouse => root.move(mouse.x, mouse.y)
        onReleased: mouse => root.release(mouse.x, mouse.y, mouse.button)
    }
}
