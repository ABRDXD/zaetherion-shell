pragma ComponentBehavior: Bound
import QtQuick

Item {
    id: handles
    required property int angle
    required property int span
    required property bool fluid
    required property color stock
    required property color paper
    required property color signal
    required property color signalInk
    required property string labelFamily
    property alias rotationTarget: rotateTab
    property alias resizeTarget: resizeTab

    component Label: Text {
        font.family: handles.labelFamily
        font.pixelSize: 13
    }

    Rectangle {
        x: 0; y: -32; width: clockName.implicitWidth + 20; height: 29
        color: handles.stock; radius: handles.fluid ? 10 : 0
        Label { id: clockName; anchors.centerIn: parent; text: "Modern Clock"; color: handles.paper }
    }
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter; y: -34
        width: 2; height: 34; color: handles.fluid ? handles.stock : handles.signal
        Rectangle {
            id: rotateTab
            anchors.horizontalCenter: parent.horizontalCenter; y: -22
            width: turnLabel.implicitWidth + 23; height: 30
            color: handles.signal; radius: handles.fluid ? 15 : 0
            Label { id: turnLabel; anchors.centerIn: parent; text: "Rotate  " + handles.angle + "°"; color: handles.signalInk }
        }
    }
    Rectangle {
        id: resizeTab
        anchors.right: parent.right; y: parent.height
        width: spanLabel.implicitWidth + 24; height: 30; color: handles.signal
        radius: handles.fluid ? 15 : 0
        Label { id: spanLabel; anchors.centerIn: parent; text: "Resize  " + handles.span + " col"; color: handles.signalInk }
    }
}
