pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland

// The login's window (Z55): over everything on the focused screen, with the keyboard so any key lands it at once.
// Made only for the 1.5 s the login plays.
PanelWindow {
    id: root
    readonly property alias sequence: sequence
    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.namespace: "zaetherion-login"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    LoginSequence {
        id: sequence
        anchors.fill: parent
        clockRect: Qt.rect(0, 0, 0, 0)  // DesktopWidgets binds the real one
        focus: true
        Keys.onPressed: event => { event.accepted = true; sequence.skip(); }
    }
}
