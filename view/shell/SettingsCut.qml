import QtQuick
import qs.view.ui

// The same 78-degree ink plane as FART's room labels, bounded inside its item.
Item {
    id: root

    property color color: Design.selected
    readonly property real run: -height * Design.shear

    Rectangle {
        x: root.run
        width: Math.max(0, root.width - root.run)
        height: root.height
        color: root.color

        transform: Matrix4x4 {
            matrix: Qt.matrix4x4(1, Design.shear, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
        }
    }
}
