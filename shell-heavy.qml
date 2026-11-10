//@ pragma UseQApplication
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic
//@ pragma Env QS_NO_RELOAD_POPUP=1
// FART's heavy layer (docs/OVERDRIVE.md §33): a second process, started on the NVIDIA card by view/shell/HeavyLayer.qml while Overdrive
// runs, drawing what the AMD chip can't under the panel. It only draws; it never takes the pointer or the keyboard. It lives on one socket
// to the panel and exits when that closes, so it can't outlive Overdrive.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.view.strata
import "view/strata/MediumLaws.js" as Laws
ShellRoot {
    id: root
    property var state: ({})
    property bool linked: false
    readonly property bool showing: !!state.showing
    readonly property bool orbit: showing && state.cx !== undefined
    property real time: 0
    property int frames: 0
    property bool readySent: false
    Socket {
        id: link
        path: Quickshell.env("FART_HEAVY_SOCKET") ?? ""
        connected: true
        parser: SplitParser { onRead: data => { try { root.state = JSON.parse(data); } catch (error) {} } }
        onConnectedChanged: {
            if (connected)
                root.linked = true;
            else if (root.linked)
                Qt.quit();
        }
    }
    // A panel that died or restarted before this process linked leaves nobody to close the socket: without this it drew on the
    // NVIDIA card for hours (10 November, docs/OVERDRIVE.md §9). Try to link for a few seconds, then give up and exit.
    property int tries: 0
    Timer {
        running: !root.linked
        interval: 500
        repeat: true
        onTriggered: {
            if (++root.tries > 16)
                Qt.quit();
            else if (!link.connected) {
                link.connected = false;
                link.connected = true;
            }
        }
    }
    // The room in view pushes the gas; arriving in one strikes it from that room's side of the sky.
    readonly property string room: state.room ?? ""
    readonly property var rooms: state.rooms ?? []
    property string lastRoom: ""
    onRoomChanged: {
        if (room && lastRoom && room !== lastRoom) {
            const b = Laws.roomBearing(room, rooms);
            if (b)
                medium.strike(b.x, b.y, 0.2, 2.6, b.dx, b.dy, 0.5, 0.8, 0.5);
        }
        if (room)
            lastRoom = room;
    }
    // Only while there's something to draw, or until the panel knows the card is up: a running FrameAnimation redraws the window every vsync.
    FrameAnimation {
        running: root.showing || (root.linked && !root.readySent)
        onTriggered: {
            root.time += frameTime;
            medium.advance(frameTime);
            medium.emitters = root.showing ? Laws.emitters(root.room, root.time, root.state.data) : [];
            if (++root.frames >= 4 && !root.readySent) {
                root.readySent = true;
                link.write("ready\n");
                link.flush();
            }
        }
    }
    PanelWindow {
        visible: true
        color: "transparent"
        // Placed exactly as the panel places itself, so the compositor puts both in the same spot.
        readonly property bool full: !!root.state.full
        anchors.top: full || root.state.edge !== "bottom"
        anchors.bottom: full || root.state.edge === "bottom"
        anchors.left: full
        anchors.right: full
        margins.top: full ? 0 : 8
        margins.bottom: full ? 0 : 8
        implicitWidth: Math.max(1, root.state.width ?? 1)
        implicitHeight: Math.max(1, root.state.height ?? 1)
        exclusionMode: full ? ExclusionMode.Ignore : ExclusionMode.Normal
        WlrLayershell.namespace: "fart-heavy"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        mask: Region {}
        Medium {
            id: medium
            anchors.fill: parent
            visible: root.showing
            running: root.showing
            sky: true
            accent: root.state.accent ?? "#a5cfdf"
            second: root.state.second ?? "#d6bdf0"
            hot: root.state.ink ?? "#edf0ed"
            deep: Qt.darker(root.state.background ?? "#151c24", 2.4)
            well: root.orbit ? ({ x: (root.state.cx ?? 0) / Math.max(1, width), y: (root.state.cy ?? 0) / Math.max(1, height), r: (root.state.radius ?? 120) / Math.max(1, height), pull: 0.5, spin: 0.9 }) : null
            light: root.orbit ? Qt.point((root.state.cx ?? 0) / Math.max(1, width), (root.state.cy ?? 0) / Math.max(1, height)) : Qt.point(0.2, 0)
        }
        ShaderEffectSource { id: mediumSight; sourceItem: medium.sight; live: root.orbit; hideSource: root.orbit; smooth: true; width: 1; height: 1; opacity: 0 }
        BlackHole {
            anchors.fill: parent
            visible: root.showing && root.orbit
            sky: mediumSight
            centreX: root.state.cx ?? width / 2
            centreY: root.state.cy ?? height / 2
            radius: root.state.radius ?? 120
            elevation: root.state.elevation ?? 45
            time: root.time
            accent: root.state.accent ?? "#a5cfdf"
            hot: root.state.ink ?? "#edf0ed"
            background: root.state.background ?? "#151c24"
        }
    }
}
