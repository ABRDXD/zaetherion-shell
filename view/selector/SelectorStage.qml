import QtQuick
import "SelectionGeometry.js" as Geometry

// One screen of the frozen selector: its part of the frozen grab under Eclipse, with Pilot light's states (Z222).
// Region mode drags a crop; window mode lights the window under the pointer and a click takes it. Release or click
// answers in slurp's format, in layout coordinates; Escape or the right button cancels. Only the screen that has the
// pointer (or the drag) is `active`; the others stay dim with a quiet label.
FocusScope {
    id: root
    property string frozen: "" // the grab's file
    property var origin: ({ x: 0, y: 0 }) // the layout's top-left, where the grab starts
    property real sourceScale: 1 // the grab's pixels per logical pixel
    property var screenRect: ({ x: 0, y: 0, width: width, height: height }) // this screen in the layout
    property string mode: "region" // "region" or "window"
    property var windows: [] // layout boxes {x, y, width, height}, window mode only
    property bool active: true // the pointer or the drag is on this screen
    property bool dragElsewhere: false // another screen holds a drag in progress
    signal picked(string answer)
    signal cancelled()
    signal entered() // the pointer arrived on this screen

    readonly property var bounds: ({ x: 0, y: 0, width: width, height: height })
    readonly property var boxes: mode === "window" ? Geometry.boxesOn(windows, screenRect) : []
    property bool dragging: false
    property real anchorX: 0
    property real anchorY: 0
    property real pointerX: width / 2
    property real pointerY: height / 2
    property bool pointerHere: false
    property var crop: null
    readonly property var shown: active ? crop : null // an inactive screen shows no crop or candidate
    readonly property alias frame: frame
    readonly property alias footer: footer
    readonly property alias quiet: quiet
    readonly property alias reticle: reticle
    readonly property string prompt: mode === "window" ? (crop ? "Click this window" : "Point at a window")
        : dragging ? "Release to select" : "Drag to select"
    // The footer sits at the bottom, moves to the top when the crop reaches the bottom and the top is free, and goes
    // when neither has room, so it never covers the crop's pixels.
    readonly property string footerPlace: {
        if (!shown)
            return "bottom";
        const h = EclipseLook.footerHeight;
        if (!Geometry.intersects(shown, { x: 0, y: height - h, width: width, height: h }))
            return "bottom";
        if (!Geometry.intersects(shown, { x: 0, y: 0, width: width, height: h }))
            return "top";
        return "none";
    }

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
        crop: root.shown
        sourceScale: root.sourceScale
        caption: root.mode === "window" ? "Window" : ""
    }
    PilotReticle {
        id: reticle
        visible: root.active && root.mode === "region" && root.pointerHere
        pointX: root.pointerX
        pointY: root.pointerY
    }
    SelectorFooter {
        id: footer
        visible: root.active && root.footerPlace !== "none"
        width: parent.width
        y: root.footerPlace === "top" ? 0 : parent.height - height
        prompt: root.prompt
    }
    QuietLabel {
        id: quiet
        visible: !root.active
        y: parent.height - EclipseLook.quietBottom - height
        text: root.dragElsewhere ? "Selection on other screen" : "Move here to select"
    }

    // The pointer's moments, called by the mouse area below (and by tests/test_selector.py's harness).
    function enter(x, y) {
        pointerHere = true;
        pointerX = x;
        pointerY = y;
        entered();
    }
    function leave() {
        pointerHere = false;
        if (mode === "window")
            crop = null; // the old candidate doesn't stay lit
    }
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
        pointerX = x;
        pointerY = y;
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
        // Region mode's pointer is the reticle; window mode keeps an ordinary arrow (Pilot light).
        cursorShape: root.mode === "region" ? Qt.BlankCursor : Qt.ArrowCursor
        onEntered: root.enter(mouseX, mouseY)
        onExited: root.leave()
        onPressed: mouse => root.press(mouse.x, mouse.y, mouse.button)
        onPositionChanged: mouse => root.move(mouse.x, mouse.y)
        onReleased: mouse => root.release(mouse.x, mouse.y, mouse.button)
    }
}
