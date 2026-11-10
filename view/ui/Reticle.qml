import qs.view.cues
import QtQuick
import QtQuick.Shapes

// Four sheared corner ticks around the focused control (MONTAGE.md §3.3). It owns no focus and draws only:
// the Shell shows it after keyboard navigation. Its rect is the target's rect in `frame` coordinates.
Item {
    id: root
    property Item frame: null
    property Item target: null
    property bool shown: false
    readonly property real arm: Math.max(0, Math.min(10, width / 3, height / 3))
    readonly property real shear: Math.tan(12 * Math.PI / 180)

    visible: shown && target !== null && frame !== null
    transformOrigin: Item.TopLeft
    transform: Matrix4x4 {
        matrix: Qt.matrix4x4(1, -root.shear, 0, height * root.shear, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
    }

    // Re-measure from the target. Called on target change and on each keyboard move; it does not track
    // scrolling of ancestors, which only moves the target while the reticle is already drawn.
    function place() {
        if (!target || !frame)
            return;
        const origin = target.mapToItem(frame, 0, 0);
        const w = target.width;
        const h = target.height;
        x = origin.x;
        y = origin.y;
        width = w;
        height = h;
    }
    onTargetChanged: place()
    onFrameChanged: place()

    // Moves settle (Motion.settle); with motion reduced the duration is 0, so it jumps.
    Tween on x { scope: root; NumberAnimation { duration: Motion.settle; easing.type: Motion.roles.settle.easing } }
    Tween on y { scope: root; NumberAnimation { duration: Motion.settle; easing.type: Motion.roles.settle.easing } }
    Tween on width { scope: root; NumberAnimation { duration: Motion.settle; easing.type: Motion.roles.settle.easing } }
    Tween on height { scope: root; NumberAnimation { duration: Motion.settle; easing.type: Motion.roles.settle.easing } }

    Shape {
        anchors.fill: parent
        antialiasing: true
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: Design.ink
            strokeWidth: 2
            fillColor: "transparent"
            PathPolyline { path: [Qt.point(0, root.arm), Qt.point(0, 0), Qt.point(root.arm, 0)] }
            PathPolyline { path: [Qt.point(root.width - root.arm, 0), Qt.point(root.width, 0), Qt.point(root.width, root.arm)] }
            PathPolyline { path: [Qt.point(root.width, root.height - root.arm), Qt.point(root.width, root.height), Qt.point(root.width - root.arm, root.height)] }
            PathPolyline { path: [Qt.point(root.arm, root.height), Qt.point(0, root.height), Qt.point(0, root.height - root.arm)] }
        }
    }
}
