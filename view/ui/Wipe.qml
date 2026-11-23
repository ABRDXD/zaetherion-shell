import qs.view.cues
import QtQuick

// The sheet's selection (MONTAGE.md §4.4): an ink plane wiping in from the left edge, its leading edge at
// 78°, with a thin rule above and below when the control is chosen. `progress` 0–1 is driven by the owner's
// state and animated here over Motion.feedback; one sheared Rectangle in a clip, so a wipe costs no
// re-tessellation. Controls read `inverted` to swap their text to the paper colour mid-wipe.
Item {
    id: root
    property bool on: false
    property bool ruled: false
    property color color: Design.ink
    property Item scope: null
    property real progress: on ? 1 : 0
    readonly property bool inverted: progress > 0.5
    readonly property color ink: inverted ? (Design.onInk ?? Design.background) : Design.ink
    readonly property real run: height * Math.tan(12 * Math.PI / 180)

    Tween on progress {
        scope: root.scope ?? root
        NumberAnimation { duration: Motion.feedback; easing.type: Easing.OutCubic }
    }
    Item {
        anchors.fill: parent
        clip: true
        visible: root.progress > 0
        Rectangle {
            // The bottom edge trails the top by `run`, so the leading edge leans at 78°; at 1 it covers all.
            width: root.progress * (root.width + root.run)
            height: root.height
            color: root.color
            transform: Matrix4x4 {
                matrix: Qt.matrix4x4(1, Design.shear, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
            }
        }
    }
    Rectangle {
        visible: root.ruled && root.progress > 0
        y: -4
        width: root.width * root.progress
        height: 1
        color: root.color
    }
    Rectangle {
        visible: root.ruled && root.progress > 0
        y: root.height + 3
        x: root.width * (1 - root.progress)
        width: root.width * root.progress
        height: 1
        color: root.color
    }
}
