import QtQuick
import Quickshell
import Quickshell.Wayland

// The frozen selector's window on one screen: a full-screen overlay layer that takes the keyboard while it lives.
PanelWindow {
    id: root
    property alias stage: stage
    signal picked(string answer)
    signal cancelled()

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "zaetherion-selector"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    color: "black"

    SelectorStage {
        id: stage
        anchors.fill: parent
        screenRect: ({ x: root.screen.x, y: root.screen.y, width: root.screen.width, height: root.screen.height })
        onPicked: answer => root.picked(answer)
        onCancelled: root.cancelled()
    }
}
