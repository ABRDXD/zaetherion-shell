import qs.view.cues
import qs.view.strata
import qs.view.ui
import QtQuick
import Quickshell
import Quickshell.Wayland

// The desktop tier (T3, D3, M16; OVERDRIVE_IDEAS #52–54): a layer over the wallpaper and under every window, which clicks
// pass straight through. While the panel is open in Overdrive, the wallpaper shows the panel's load as stress fringes,
// and one meridian, a single pixel wide, runs the height of the screen through the current room's title edge. It moves
// only on a room switch. When the panel closes while Overdrive goes on, a small residue of what you last did stays on
// the wallpaper for a quarter of a minute, then is gone. The whole surface exists only while one of those is true.
PanelWindow {
    id: root
    // The panel's rect on this screen (empty while it is shut), the meridian's x, the room's number and the residue.
    property bool eigenOnly: false
    property rect panelRect: Qt.rect(0, 0, 0, 0)
    property real meridianX: -1
    property int roomTurn: 0
    property string residue: ""
    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.namespace: "fart-desktop"
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    // An empty input region: every click goes through to the desktop.
    mask: Region {}
    Stratum {
        name: "stress"
        tier: "desktop"
        wanted: root.panelRect.width > 0
        anchors.fill: parent
        sourceComponent: StressField {
            panelRect: root.panelRect
            turnValue: root.roomTurn
        }
    }
    Stratum {
        anchors.fill: parent; name:"eigenmode.desktop"; tier:"desktop"; gpu:false
        wanted:Motion.overdrive && !root.eigenOnly
        sourceComponent: EigenDiagram { desktopTier:true }
    }
    Loader {
        anchors.fill:parent
        active:root.eigenOnly && Eigenmode.still
        sourceComponent:EigenDiagram { desktopTier:true; still:true }
    }
    Rectangle {
        visible: root.meridianX >= 0 && root.panelRect.width > 0
        x: root.meridianX
        width: 1
        height: parent.height
        color: Qt.alpha(Design.accent, 0.55 * Motion.drive)
    }
    Plane {
        visible: root.residue !== ""
        x: parent.width * 0.5 - width / 2
        y: parent.height * 0.42
        width: residueText.implicitWidth + 34
        height: 26
        role: "ink"
        slant: 3
        backing: true
        FText {
            id: residueText
            anchors.centerIn: parent
            text: root.residue
            technical: true
            color: parent.textColor
        }
    }
}
