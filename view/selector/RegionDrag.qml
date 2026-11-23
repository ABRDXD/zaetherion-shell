import QtQuick
import "SelectionGeometry.js" as Geometry

// A region drag on one screen, shared by the frozen selector and the live recording picker: press anchors, move
// spans a crop once the pointer has travelled (MIN_DRAG), release returns the crop or null (a click is not a crop).
QtObject {
    property var bounds: ({ x: 0, y: 0, width: 0, height: 0 })
    property bool dragging: false
    property real anchorX: 0
    property real anchorY: 0
    property var crop: null

    function press(x, y) {
        anchorX = x;
        anchorY = y;
        crop = null;
        dragging = true;
    }
    function move(x, y) {
        if (dragging && Geometry.isDrag(anchorX, anchorY, x, y))
            crop = Geometry.span(anchorX, anchorY, x, y, bounds);
    }
    function release() {
        dragging = false;
        const done = crop && crop.width > 0 && crop.height > 0 ? crop : null;
        if (!done)
            crop = null;
        return done;
    }
}
