import QtQuick

// A registration cross: the sheet's corner mark. Centred on its own position.
Item {
    id: root
    property color color: Design.faint
    property int arm: 6
    width: arm * 2 + 1
    height: arm * 2 + 1
    Rectangle { x: 0; y: root.arm; width: parent.width; height: 1; color: root.color }
    Rectangle { x: root.arm; y: 0; width: 1; height: parent.height; color: root.color }
}
