import QtQuick
import QtQuick.Shapes

// The montage's only surface (MONTAGE.md §3.1). Two renderers behind one API: a sheared Rectangle for
// planes with no cut and parallel slants (batches with other rectangles), and a Shape for cut or
// one-sided slants. Geometry is computed from width and height, so it changes only on resize.
Item {
    id: root
    property string role: "paper"   // paper | ink | signal | clear
    property int slant: 0          // bit 1: left edge at 78°, bit 2: right edge at 78°, 3: both
    property real cut: 0           // corner cut, px
    property bool backing: false   // carries small text, so it is always opaque
    property int depth: 0          // layer order 0–2; Silent never animates it

    readonly property real shear: Math.tan(12 * Math.PI / 180)   // horizontal run per vertical px of a 78° edge
    readonly property real run: height * shear
    readonly property bool sheared: cut === 0 && (slant === 0 || slant === 3)
    // A backing plane never ends up transparent: small text needs an opaque surface under it.
    readonly property string effectiveRole: role === "clear" && backing ? "paper" : role
    readonly property color fillColor: effectiveRole === "ink" ? Design.ink
        : effectiveRole === "signal" ? Design.accent
        : effectiveRole === "paper" ? Design.surface : "transparent"
    // onInk/onSignal arrive with the contrast guard (m6-contrast); until it merges, the unguarded background.
    readonly property color textColor: effectiveRole === "ink" ? (Design.onInk ?? Design.background)
        : effectiveRole === "signal" ? (Design.onSignal ?? Design.background) : Design.ink

    readonly property var polygon: cutCorners([
        Qt.point(slant & 1 ? run : 0, 0),
        Qt.point(width, 0),
        Qt.point(slant & 2 ? width - run : width, height),
        Qt.point(0, height)
    ], cut)

    z: depth

    // Each corner is replaced by two points on its adjacent edges, `size` px from the vertex.
    function cutCorners(points, size) {
        if (size <= 0)
            return points;
        const out = [];
        for (let i = 0; i < points.length; i++) {
            const p = points[i];
            out.push(towards(p, points[(i + points.length - 1) % points.length], size));
            out.push(towards(p, points[(i + 1) % points.length], size));
        }
        return out;
    }
    function towards(p, q, size) {
        const dx = q.x - p.x;
        const dy = q.y - p.y;
        const len = Math.hypot(dx, dy);
        const t = len > 0 ? Math.min(size, len / 2) / len : 0;
        return Qt.point(p.x + dx * t, p.y + dy * t);
    }

    Rectangle {
        // Shear about the top-left: the top edge moves right by `run`, the bottom stays on the origin.
        visible: root.sheared
        transformOrigin: Item.TopLeft
        x: 0
        y: 0
        width: root.width - (root.slant === 3 ? root.run : 0)
        height: root.height
        color: root.fillColor
        transform: Matrix4x4 {
            matrix: Qt.matrix4x4(1, root.slant === 3 ? -root.shear : 0, 0, root.slant === 3 ? root.run : 0,
                0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
        }
    }
    Shape {
        anchors.fill: parent
        visible: !root.sheared
        antialiasing: true
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: "transparent"
            fillColor: root.fillColor
            PathPolyline { path: root.polygon }
        }
    }
}
