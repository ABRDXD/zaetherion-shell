import QtQuick

// A 1 px rule that ends in small solid squares, the sheet's ruling line. Horizontal only.
Item {
    id: root
    property color color: Design.line
    property bool startNode: false
    property bool endNode: true
    property int node: 5
    implicitHeight: node
    implicitWidth: 40
    Rectangle {
        x: root.startNode ? root.node : 0
        width: parent.width - x - (root.endNode ? root.node : 0)
        height: 1
        anchors.verticalCenter: parent.verticalCenter
        color: root.color
    }
    Rectangle {
        visible: root.startNode
        width: root.node
        height: root.node
        color: root.color
    }
    Rectangle {
        visible: root.endNode
        x: parent.width - width
        width: root.node
        height: root.node
        color: root.color
    }
}
