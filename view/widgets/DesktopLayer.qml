pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland

// One screen's desktop widgets (SURFACES §7, layer Bottom: over the wallpaper, under every window). DesktopWidgets
// makes this window only while the screen's workspace is empty, so an occupied workspace has no widget, no surface
// and no fonts loaded (Z85); emptying it rebuilds the clock at its saved pose. It takes the bare desktop's clicks
// (there is no window here to give them to): a right-click opens the desktop menu (Z86).
PanelWindow {
    id: root
    property var widgets: null
    readonly property alias stage: stage
    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.namespace: "zaetherion-desktop"
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    DesktopStage {
        id: stage
        anchors.fill: parent
        widgets: root.widgets
        monitor: root.screen?.name ?? ""
    }
}
