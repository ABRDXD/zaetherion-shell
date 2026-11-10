import QtQuick
import QtQuick.Controls
import qs.view.ui

AbstractButton {
    id: root
    property string kind: ""
    property real seconds: 0
    property bool running: false
    property bool done: false
    property bool selected: false
    implicitHeight: 58
    hoverEnabled: true
    Accessible.name: kind + ", " + (done ? "done" : Clock.formatSeconds(seconds)) + (running ? ", running" : ", held")
    background: Plane { id: plane; role: root.selected ? "ink" : "paper"; backing: true; slant: 2 }
    contentItem: Item {
        Rectangle { x: 0; y: 0; width: root.selected || root.hovered || root.activeFocus ? 4 : 2; height: parent.height; color: Design.accent }
        FText { x: 12; y: 7; text: root.kind === "pomodoro" ? "FOCUS" : root.kind; technical: true; color: plane.textColor }
        FText { x: 12; y: 24; text: root.done ? "DONE" : Clock.formatSeconds(root.seconds); headline: true; font.pixelSize: Design.readout; font.weight: Font.DemiBold; color: plane.textColor }
        FText { anchors.right: parent.right; anchors.rightMargin: 20; y: 30; text: root.running ? "RUN" : "HELD"; technical: true; color: plane.textColor }
    }
}
