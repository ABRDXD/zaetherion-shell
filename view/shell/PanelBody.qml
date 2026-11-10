import QtQuick
import qs.core.client
import qs.view.contract
import qs.view.cues
import qs.view.ui as Fart

// The panel as drawn: the frame, its unfold about the clock's origin, and Shell. Shared by Overlay
// (the layer surface) and the desktop fixture view (a FloatingWindow), so both measure one path.
Item {
    id: root
    // The heavy layer is drawing under the panel: the panel lets it show.
    property bool spaceShows: false
    // On the orbit the panel has no backing at all; in a room it keeps enough to read by, and the Medium moves behind the room.
    property bool spaceOnOrbit: false
    required property HostAdapter host
    required property CoreClient core
    required property ShellContext context
    required property Unfold unfold
    // Shell exists while the panel is open or folding.
    property bool retained: false
    // DAILY_DRIVER Q2: Shell stays loaded while folded (its room is still released), so a warm open
    // only incubates the room. Measured: warm first frame 6.8–7.5 ms instead of 10.3–16.6 ms, closed
    // PSS within noise (docs/M5-VIEW.md).
    property bool keepShell: true
    property bool loadedOnce: false
    onRetainedChanged: if (!retained && dashboard.item) dashboard.item.releaseRoom()
    // The room asked for; `show` navigates an existing Shell.
    property string page: "home"
    // Where the body grows from, in panel coordinates (DAILY_DRIVER §3): the clock's centre-x on
    // the panel's bar-side edge. `edge` "bottom" mirrors the rise into a drop.
    property point origin: Qt.point(width / 2, 0)
    property string edge: "top"
    readonly property Shell shell: dashboard.item
    readonly property real bodyScale: unfold.bodyScale
    // Overdrive's black hole (docs/OVERDRIVE.md §8): with the engine on, the panel falls into the clock it came
    // from as it folds (shrinking to a point at the origin, stretched towards it and swirling in), and an open is
    // the same in reverse, a small big bang out of the clock. 0 when open, and always 0 in Silent.
    readonly property real hole: Motion.drive * (1 - Math.min(1, Math.max(0, unfold.body.value)))
    readonly property real holeX: 1 - 0.985 * hole
    readonly property real holeY: 1 - 0.985 * Math.pow(hole, 2.2)
    readonly property real holeAngle: (edge === "bottom" ? 1 : -1) * 220 * Math.pow(hole, 1.6)
    readonly property real bodyRise: edge === "bottom" ? -unfold.bodyRise : unfold.bodyRise
    // The frame as drawn (scaled about the origin and risen): regions follow item geometry, not transforms.
    readonly property Item shape: bodyShape
    // Once per open: the first frame swapped after the command line has active focus in an active
    // window. The cold-start and warm-open budgets end here (DAILY_DRIVER §1).
    property bool awaitingInteractive: false
    signal interactive()
    signal loaded()

    function show(requested) {
        page = requested;
        if (dashboard.item && (dashboard.item.currentPage !== requested || !dashboard.item.shownSlot.item))
            dashboard.item.navigate(requested);
    }
    function focusCommandLine() {
        dashboard.item?.focusCommandLine();
    }
    function armInteractive() {
        awaitingInteractive = true;
    }
    // A position clamped to the panel's width, from a clock rect in screen coordinates and the
    // panel's left edge on that screen.
    function originFrom(rect, panelLeft) {
        if (!rect || !(rect.width > 0))
            return Qt.point(width / 2, edge === "bottom" ? height : 0);
        const x = rect.x + rect.width / 2 - panelLeft;
        return Qt.point(Math.max(0, Math.min(width, x)), edge === "bottom" ? height : 0);
    }

    Connections {
        target: root.Window.window
        enabled: root.awaitingInteractive && root.Window.active && (dashboard.item?.commandLine.inputFocused ?? false)
        function onFrameSwapped() {
            root.awaitingInteractive = false;
            root.interactive();
        }
    }
    Item {
        id: bodyShape
        width: root.width * root.bodyScale
        height: root.height * root.bodyScale
        x: root.origin.x * (1 - root.bodyScale)
        y: root.origin.y * (1 - root.bodyScale) + root.bodyRise
    }
    Rectangle {
        id: frame
        width: root.width
        height: root.height
        opacity: Math.min(1, root.unfold.body.value)
        transform: [
            Scale { origin.x: root.origin.x; origin.y: root.origin.y; xScale: root.bodyScale; yScale: root.bodyScale },
            Scale { origin.x: root.origin.x; origin.y: root.origin.y; xScale: root.holeX; yScale: root.holeY },
            Rotation { origin.x: root.origin.x; origin.y: root.origin.y; angle: root.holeAngle },
            Translate { y: root.bodyRise }
        ]
        radius: Fart.Design.radiusPanel
        color: root.spaceShows ? (root.spaceOnOrbit ? "transparent" : Qt.alpha(Fart.Design.background, 0.62)) : Qt.alpha(Fart.Design.background, Fart.Design.panelOpacity)
        clip: true
        Keys.onEscapePressed: Host.close()
        Loader {
            id: dashboard
            // Keep the dashboard layout stable throughout the reveal.
            width: root.width
            height: root.height
            active: root.retained || (root.keepShell && root.loadedOnce)
            visible: root.retained
            sourceComponent: Shell {
                host: root.host
                shell: root.context
                core: root.core
                page: root.page
                headerReveal: root.unfold.header.value
                headerRise: root.unfold.headerRise
                roomReveal: root.unfold.room.value
                roomRise: root.unfold.roomRise
                onCurrentPageChanged: Host.page = currentPage
            }
            onLoaded: {
                root.loadedOnce = true;
                Host.page = item.currentPage;
                item.focusCommandLine();
                root.loaded();
            }
        }
    }
    // The event horizon: a ring at the clock that flares while the panel falls through it (Overdrive only).
    Rectangle {
        readonly property real flare: 4 * root.hole * (1 - root.hole)
        visible: flare > 0.01
        width: 10 + 70 * root.hole
        height: width
        radius: width / 2
        x: root.origin.x - width / 2
        y: root.origin.y - height / 2
        color: Qt.alpha(Fart.Design.background, 0.85 * flare)
        border.width: 2 + 3 * flare
        border.color: Qt.alpha(Fart.Design.accent, flare)
        Rectangle {
            anchors.centerIn: parent
            width: parent.width * 1.6
            height: width
            radius: width / 2
            color: "transparent"
            border.width: 1
            border.color: Qt.alpha(Fart.Design.warm, 0.6 * parent.flare)
        }
    }
}
