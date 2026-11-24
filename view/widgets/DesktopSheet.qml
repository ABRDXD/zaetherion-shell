pragma ComponentBehavior: Bound
import QtQuick
import qs.view.ui

// Over one screen while the desktop menu or the widget editor is open (Z86). The menu sits at the right-click,
// kept inside the screen; a click outside it or Escape dismisses it. Edit widgets opens the placement the form
// was picked with (Angular: Chase, Fluid: Margin); Wallpaper, Theme and Settings open FART's Settings there.
FocusScope {
    id: root
    property string mode: "menu"  // "menu" or "edit"
    property point at
    property string monitor: ""
    property var widgets: null
    property string wallpaper: ""
    property bool fluid: Design.fluid
    signal dismissed()
    signal openSettings(string section)
    signal placed(var pose)
    readonly property Item menu: menuLoader.item
    readonly property Item editor: editorLoader.item
    focus: true

    // The four rows and where they go (Theme is the palette, Z213; Settings keeps the tab last shown).
    function choose(label) {
        if (label === "Edit widgets") {
            mode = "edit";
            return;
        }
        // Ask first: dismissing unloads this sheet, and with it the connection that carries the request.
        root.openSettings(label === "Wallpaper" ? "wallpaper" : label === "Theme" ? "palette" : "current");
        root.dismissed();
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.mode === "menu"
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onPressed: root.dismissed()
    }
    Loader {
        id: menuLoader
        active: root.mode === "menu"
        x: Math.max(0, Math.min(root.at.x, root.width - width))
        y: Math.max(0, Math.min(root.at.y, root.height - height))
        focus: active
        onLoaded: item.forceActiveFocus()
        sourceComponent: DesktopMenu {
            objectName: "desktopMenu"
            fluid: root.fluid
            fontFamily: root.fluid ? "Noto Sans" : "Roboto Condensed"
            onDismissed: root.dismissed()
            onChosen: label => root.choose(label)
        }
    }
    Loader {
        id: editorLoader
        anchors.fill: parent
        active: root.mode === "edit"
        focus: active
        onLoaded: item.forceActiveFocus()
        sourceComponent: DesktopEditor {
            fluid: root.fluid
            monitor: root.monitor
            screenSize: Qt.size(root.width, root.height)
            widgets: root.widgets
            wallpaper: root.wallpaper
            onPlaced: pose => root.placed(pose)
            onClosed: root.dismissed()
        }
    }
}
