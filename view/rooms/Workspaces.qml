import QtQuick
import QtQuick.Controls
import QtQuick.Shapes
import qs.view.contract
import qs.view.shell
import qs.view.ui
import qs.view.cues
import "WorkspacesOrbit.js" as Orbit

// Workspaces as an orbit (Z209, owner's pick "B · The orbit", 16 November 2026). The desks ride one tilted ring
// round a small star; the current desk is swung to the front, big, its windows riding a small orbit round it as
// named moons. Occupied desks are lit in a star colour that burns hotter with more windows; empty ones are dark
// discs; a desk emptied today keeps a faint shell. Hover on a desk looks at it: the headline
// and the window blades below follow, the ring stays put. A click goes there, and the ring swings the short way
// round. Below: the inspected desk's windows as blades, then Go there / Focus / Move to….
// In Overdrive the moons drift on their orbit (one IdleLoop); Silent is still.
Item {
    id: root
    required property HostAdapter host
    required property ShellContext shell
    property var historyOverride: null
    readonly property var wm: host.workspaces
    readonly property bool narrow: width < 730
    readonly property int count: Math.max(7, Math.min(12, Config.options.bar.workspaces.shown))
    readonly property int current: Number(wm.activeId) || 1
    property int looking: 0
    readonly property int inspected: looking || current
    readonly property var history: historyOverride || feed.snapshot
    readonly property var inspectedWindows: windowsOn(inspected)
    readonly property var currentWindows: windowsOn(current)
    // The window the actions act on: the one picked, else the desk's focused one.
    property int picked: -1
    readonly property int selectedIndex: picked >= 0 && picked < inspectedWindows.length ? picked : Orbit.selected(inspectedWindows)
    readonly property var selectedWindow: inspectedWindows[selectedIndex] ?? null
    // Move mode: the next desk clicked receives the window chosen when Move was pressed (looking elsewhere
    // while choosing must not change it).
    property var carried: null
    readonly property bool moving: carried !== null

    // Geometry, as shares of the room.
    readonly property real ringCentreY: 0.36
    readonly property real ringWidth: narrow ? 0.44 : 0.4
    readonly property real moonOrbit: 1.45
    readonly property var ring: Orbit.ring(width * ringWidth)
    readonly property point centre: Qt.point(width / 2, height * ringCentreY)
    readonly property real frontSize: Orbit.size(1, true, true, height)

    // The ring turns by whole desks, the short way round, and eases there.
    property real turnTarget: current - 1
    property real turn: turnTarget
    Tween on turn { scope: root; NumberAnimation { duration: Motion.transfer; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }
    onCurrentChanged: turnTarget += Orbit.shortest(Math.round(turnTarget), current - 1, count)
    onCountChanged: turnTarget = current - 1
    onInspectedChanged: picked = -1

    GenealogyFeed { id: feed; visible: root.visible && !root.historyOverride }
    IdleLoop { id: drift; scope: root; name: "workspaces.moons"; period: 24000; enabled: root.currentWindows.length > 0 }

    function windowsOn(number) { return wm.windows.filter(w => Number(w.workspaceId) === number); }
    function deskWarmth(windows) { return Design.spectral[Math.max(0, Orbit.warmth(windows, Design.spectral.length))]; }
    function go(number) {
        if (moving) {
            wm.moveWindow(String(carried.id), String(number));
            carried = null;
            return;
        }
        looking = 0;
        wm.switchTo(String(number));
    }

    // The primary reading: the inspected desk and what is on it.
    Row {
        id: heading
        spacing: 18
        FText {
            id: deskNumber
            text: String(root.inspected).padStart(2, "0")
            headline: true
            font.pixelSize: Design.display
            font.weight: Font.Black
            font.letterSpacing: -5
        }
        Column {
            y: deskNumber.height - height - 10
            spacing: 4
            FText {
                text: root.moving ? "MOVING " + (root.carried.appId || "WINDOW") + " · PICK A DESK" : root.inspected === root.current ? "DESK · HERE" : "DESK · LOOKING"
                technical: true
                color: root.inspected === root.current || root.moving ? Design.accent : Design.muted
            }
            FText {
                text: Orbit.summary(root.inspectedWindows)
                headline: true
                font.pixelSize: Design.readout
                font.weight: Font.Bold
                font.capitalization: Font.MixedCase
            }
        }
    }
    FText {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: 8
        visible: !root.narrow
        horizontalAlignment: Text.AlignRight
        text: root.wm.windows.length + " windows · " + root.wm.workspaces.filter(w => w.windowCount > 0).length
              + " desks lit\nhover a desk to look · click to go"
        technical: true
        color: Design.muted
        lineHeight: 1.5
    }

    // The ring and its star.
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: Qt.alpha(Design.line, 0.7)
            strokeWidth: 1
            fillColor: "transparent"
            PathAngleArc { centerX: root.centre.x; centerY: root.centre.y; radiusX: root.ring.rx; radiusY: root.ring.ry; startAngle: 0; sweepAngle: 360 }
        }
        ShapePath {
            strokeColor: Qt.alpha(Design.line, 0.3)
            strokeWidth: 1
            strokeStyle: ShapePath.DashLine
            dashPattern: [2, 6]
            fillColor: "transparent"
            PathAngleArc { centerX: root.centre.x; centerY: root.centre.y; radiusX: root.ring.rx * 1.08; radiusY: root.ring.ry * 1.13; startAngle: 0; sweepAngle: 360 }
        }
    }
    ColdStar { x: root.centre.x - radius; y: root.centre.y - radius; radius: 14 }

    // The desks.
    Repeater {
        model: root.count
        Item {
            id: slot
            required property int index
            readonly property int number: index + 1
            readonly property var where: Orbit.place(index, root.turn, root.count)
            readonly property var windows: root.windowsOn(number)
            readonly property bool front: number === root.current
            x: root.centre.x + root.ring.rx * where.cos
            y: root.centre.y + root.ring.ry * where.sin
            z: Math.round(where.depth * 20)
            opacity: front ? 1 : 0.35 + 0.65 * where.depth
            WorkspacePlanet {
                number: slot.number
                windows: slot.windows.length
                size: Orbit.size(slot.where.depth, slot.windows.length > 0, slot.front, root.height)
                depth: slot.where.depth
                front: slot.front
                current: slot.front
                litRight: slot.where.cos < 0
                star: root.deskWarmth(slot.windows.length)
                remembered: !!root.history?.memories?.[String(slot.number)]
                onLook: on => root.looking = on ? slot.number : root.looking === slot.number ? 0 : root.looking
                onClicked: root.go(slot.number)
            }
        }
    }

    // The current desk's windows ride a small orbit round it, named.
    Item {
        id: moons
        x: root.centre.x
        y: root.centre.y + root.ring.ry
        z: 30
        readonly property real rx: root.frontSize * root.moonOrbit
        readonly property real ry: rx * 0.2
        Shape {
            x: -moons.rx
            y: -moons.ry
            width: moons.rx * 2
            height: moons.ry * 2
            visible: root.currentWindows.length > 0
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: Qt.alpha(Design.accent, 0.5)
                strokeWidth: 1
                fillColor: "transparent"
                PathAngleArc { centerX: moons.rx; centerY: moons.ry; radiusX: moons.rx; radiusY: moons.ry; startAngle: 0; sweepAngle: 360 }
            }
        }
        Repeater {
            model: root.currentWindows
            Item {
                id: moon
                required property var modelData
                required property int index
                readonly property real angle: Math.PI / 2 + (index / Math.max(1, root.currentWindows.length)) * 2 * Math.PI + 0.9
                                              + drift.phase * 2 * Math.PI * drift.level
                readonly property bool lead: root.current === root.inspected && index === root.selectedIndex
                z: Math.sin(angle) > 0 ? 2 : -1
                transform: Translate { x: moons.rx * Math.cos(moon.angle); y: moons.ry * Math.sin(moon.angle) }
                Rectangle {
                    x: -width / 2; y: -height / 2
                    width: moon.lead ? 14 : 10; height: width; radius: width / 2
                    color: moon.lead ? Design.accent : Design.coldStar
                }
                FText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 12
                    text: moon.modelData.appId || "window"
                    technical: true
                    color: moon.lead ? Design.accent : Design.ink
                }
            }
        }
    }

    // What you act on: the inspected desk's windows, then the actions.
    Row {
        id: blades
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: actions.top
        anchors.bottomMargin: 14
        spacing: 10
        readonly property int slots: root.narrow ? 3 : 5
        readonly property int shown: Math.min(slots, root.inspectedWindows.length)
        // Fixed slots, refilled in place: a live window list must not recreate them (keyboard focus would drop).
        Repeater {
            model: blades.slots
            WindowBlade {
                required property int index
                readonly property var window: root.inspectedWindows[index] ?? null
                visible: index < blades.shown
                width: (blades.width - (blades.shown - 1) * blades.spacing) / Math.max(1, blades.shown)
                height: implicitHeight
                app: window?.appId || "window"
                title: window?.title || ""
                selected: index === root.selectedIndex
                onClicked: {
                    if (selected && root.inspected === root.current) root.wm.focusWindow(String(window.id));
                    root.picked = index;
                }
            }
        }
        FText {
            visible: !root.inspectedWindows.length
            height: 88
            verticalAlignment: Text.AlignVCenter
            text: "Nothing open here · Super + " + root.inspected + " and launch something"
            technical: true
            color: Design.muted
        }
    }
    Row {
        id: actions
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        spacing: 10
        FButton {
            visible: root.inspected !== root.current && !root.moving
            primary: true
            label: "Go to desk " + String(root.inspected).padStart(2, "0")
            onClicked: root.go(root.inspected)
        }
        FButton {
            visible: !!root.selectedWindow && !root.moving
            primary: root.inspected === root.current
            label: "Focus " + (root.selectedWindow?.appId || "window")
            onClicked: {
                if (root.inspected !== root.current) root.wm.switchTo(String(root.inspected));
                root.wm.focusWindow(String(root.selectedWindow.id));
            }
        }
        FButton {
            visible: !!root.selectedWindow || root.moving
            selected: root.moving
            label: root.moving ? "Cancel move" : "Move " + (root.selectedWindow?.appId || "window") + " to…"
            onClicked: root.carried = root.moving ? null : root.selectedWindow
        }
        FText {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.moving
            text: "click a desk on the ring"
            technical: true
            color: Design.accent
        }
    }
}
