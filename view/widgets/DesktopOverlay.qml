pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland

// The desktop menu and the widget editor's window (Top layer, the keyboard while open). Made by DesktopWidgets
// only while one of them is open on this screen.
PanelWindow {
    id: root
    readonly property alias sheet: sheet
    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.namespace: "zaetherion-desktop-edit"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    DesktopSheet {
        id: sheet
        anchors.fill: parent
        monitor: root.screen?.name ?? ""
    }
}
