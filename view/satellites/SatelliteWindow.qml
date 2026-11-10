import QtQuick
import Quickshell
import Quickshell.Wayland

// The satellites' one layer surface, beside the clock rect (below it on a top bar). No keyboard
// focus, no exclusive zone; the input region is the surface itself, which is only as big as its cards.
PanelWindow {
    id: root
    // The clock rect in this screen's coordinates: { x, y, width, height, edge }.
    property var rect: ({ x: 0, y: 0, width: 0, height: 40, edge: "top" })
    readonly property bool bottom: rect.edge === "bottom"
    anchors.top: !bottom
    anchors.bottom: bottom
    anchors.left: true
    margins.top: bottom ? 0 : rect.y + rect.height + 6
    margins.bottom: bottom ? Math.max(0, screen.height - rect.y) + 6 : 0
    margins.left: Math.max(0, Math.min(screen.width - implicitWidth, Math.round(rect.x + rect.width / 2 - implicitWidth / 2)))
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    // As big as the cards Satellites places in the content item.
    implicitWidth: Math.max(1, contentItem.childrenRect.width)
    implicitHeight: Math.max(1, contentItem.childrenRect.height)
    WlrLayershell.namespace: "fart-satellite"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
}
