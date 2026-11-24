pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import qs.view.cues
import qs.view.ui

// Desktop widgets on every screen (Z46, Z85, SURFACES §7). A screen's layer exists only while its active
// workspace has no window: a window arriving destroys the clock and its surface; the last one leaving rebuilds
// it at the pose the core keeps for that monitor (core/widgets.py).
Scope {
    id: root
    property bool wanted: true
    // A WorkspacesDomain: workspaces [{id, monitor, active, windowCount}].
    property var workspaces: null
    property var core: null
    // Tests: the same stage in a plain window per screen (layer shell needs a compositor).
    property bool fixture: false
    // Each screen's DesktopStage while it exists, for the editor and the login.
    readonly property var stages: Array.from(variants.instances).map(slot => slot.stage).filter(Boolean)
    // Each playing login (LoginSequence), for tests.
    function loginSequences() { return Array.from(variants.instances).map(slot => slot.login).filter(Boolean); }
    // Each open desktop menu or editor (DesktopSheet), for tests.
    readonly property var sheets: Array.from(variants.instances).map(slot => slot.sheet).filter(Boolean)
    // Wallpaper, Theme and Settings from the desktop menu: the shell opens its Settings at that section.
    signal openSettings(string section)

    // The login (Z55, Angular only; Fluid has no approved login yet). tools/session-start leaves a one-time marker in
    // the runtime folder ("login"); the first view after login plays on the focused screen and marks it "played".
    // Reduced motion lands at once (no sequence). Tests set `arrival` themselves.
    property var arrival: null         // the screen the login plays on, null when none
    property bool arrivalChecked: fixture
    readonly property string focusedScreen: root.workspaces?.focusedScreen ?? ""
    // Where a login plays: the focused screen, in Angular, with motion on; null when it doesn't.
    function arrivalFor(loggedIn) {
        if (!loggedIn || Design.fluid || Motion.reduced) return null;
        return Quickshell.screens.find(screen => screen.name === root.focusedScreen) ?? Quickshell.screens[0] ?? null;
    }
    // Read, then marked "played", so a view restart or a live restart finds nothing to play (no process needed).
    FileView {
        path: root.wanted && !root.fixture ? (Quickshell.env("XDG_RUNTIME_DIR") ?? "") + "/zaetherion/arrival" : ""
        printErrors: false
        onLoaded: {
            const login = text().trim() === "login";
            if (login) setText("played\n");
            root.arrival = root.arrivalFor(login);
            root.arrivalChecked = true;
        }
        onLoadFailed: root.arrivalChecked = true  // no marker: no login to play
    }

    function place(monitor, pose) {
        root.core?.request("widgets.place", { monitor: monitor, column: pose.column, span: pose.span, y: pose.y, angle: pose.angle },
                           (ok, result) => { if (!ok) console.warn("widgets.place: " + (result?.message ?? "failed")); });
    }

    function occupied(monitor) {
        const spaces = root.workspaces?.workspaces ?? [];
        const shown = spaces.find(space => space.monitor === monitor && space.active);
        return (shown?.windowCount ?? 0) > 0;
    }

    Variants {
        id: variants
        model: root.wanted ? Quickshell.screens : []
        Scope {
            id: slot
            required property var modelData
            readonly property string monitor: modelData?.name ?? ""
            readonly property bool empty: !root.occupied(monitor)
            readonly property bool arriving: root.arrival !== null && root.arrival === slot.modelData
            readonly property var stage: layer.item?.stage ?? fixtureLayer.item?.stage ?? null
            readonly property var sheet: overlay.item?.sheet ?? fixtureOverlay.item?.sheet ?? null
            property string sheetMode: ""  // "", "menu" or "edit"
            property point sheetAt
            Connections {
                target: slot.stage
                function onMenuRequested(at) { slot.sheetAt = at; slot.sheetMode = "menu"; }
            }
            Connections {
                target: slot.sheet
                function onDismissed() { slot.sheetMode = ""; }
                function onOpenSettings(section) { root.openSettings(section); }
                function onPlaced(pose) { root.place(slot.monitor, pose); }
            }
            function dress(sheet) {
                sheet.mode = slot.sheetMode;
                sheet.at = slot.sheetAt;
                sheet.widgets = Qt.binding(() => root.core?.widgetsData ?? null);
                sheet.wallpaper = Qt.binding(() => root.core?.wallpaperData?.applied ?? "");
            }
            readonly property var login: loginLayer.item?.sequence ?? fixtureLogin.item?.sequence ?? null
            // Never hold the clock back for good: a login that hasn't landed 3 s after it began (it takes 1.5 s; a
            // window that failed to load never would) is let go.
            Timer {
                running: slot.arriving
                interval: 3000
                onTriggered: { console.warn("login did not land; showing the desktop"); root.arrival = null; }
            }
            function dressLogin(sequence) {
                sequence.clockRect = Qt.binding(() => slot.stage?.clockRect ?? Qt.rect(0, 0, 0, 0));
                sequence.angle = Qt.binding(() => slot.stage?.pose.angle ?? 0);
                sequence.occupied = Qt.binding(() => !slot.empty);
                sequence.face = root.core?.widgetsData?.face ?? ({});
                sequence.finished.connect(() => root.arrival = null);
                sequence.forceActiveFocus();
                sequence.start();
            }
            LazyLoader {
                id: loginLayer
                active: slot.arriving && !root.fixture
                source: Qt.resolvedUrl("LoginOverlay.qml")
                onItemChanged: if (item) { item.screen = slot.modelData; slot.dressLogin(item.sequence); }
            }
            LazyLoader {
                id: fixtureLogin
                active: slot.arriving && root.fixture
                onItemChanged: if (item) slot.dressLogin(item.sequence)
                FloatingWindow {
                    readonly property alias sequence: fixtureSequence
                    screen: slot.modelData
                    implicitWidth: slot.modelData?.width ?? 1920
                    implicitHeight: slot.modelData?.height ?? 1080
                    color: "transparent"
                    LoginSequence {
                        id: fixtureSequence
                        anchors.fill: parent
                        clockRect: Qt.rect(0, 0, 780, 209)
                        Keys.onPressed: event => { event.accepted = true; fixtureSequence.skip(); }
                    }
                }
            }
            LazyLoader {
                id: overlay
                active: slot.sheetMode !== "" && !root.fixture
                source: Qt.resolvedUrl("DesktopOverlay.qml")
                onItemChanged: if (item) { item.screen = slot.modelData; slot.dress(item.sheet); }
            }
            LazyLoader {
                id: fixtureOverlay
                active: slot.sheetMode !== "" && root.fixture
                onItemChanged: if (item) slot.dress(item.sheet)
                FloatingWindow {
                    readonly property alias sheet: fixtureSheet
                    screen: slot.modelData
                    implicitWidth: slot.modelData?.width ?? 1920
                    implicitHeight: slot.modelData?.height ?? 1080
                    color: "transparent"
                    DesktopSheet { id: fixtureSheet; anchors.fill: parent; monitor: slot.monitor }
                }
            }
            // By URL, so Qt's offscreen tests (no layer shell) never load the type.
            LazyLoader {
                id: layer
                active: slot.empty && !root.fixture
                source: Qt.resolvedUrl("DesktopLayer.qml")
                onItemChanged: if (item) {
                    item.screen = slot.modelData;
                    item.widgets = Qt.binding(() => root.core?.widgetsData ?? null);
                    item.stage.clockHidden = Qt.binding(() => slot.arriving || !root.arrivalChecked);
                }
            }
            LazyLoader {
                id: fixtureLayer
                active: slot.empty && root.fixture
                FloatingWindow {
                    readonly property alias stage: fixtureStage
                    screen: slot.modelData
                    implicitWidth: slot.modelData?.width ?? 1920
                    implicitHeight: slot.modelData?.height ?? 1080
                    color: "#16191e"
                    DesktopStage {
                        id: fixtureStage
                        anchors.fill: parent
                        widgets: root.core?.widgetsData ?? null
                        monitor: slot.monitor
                        clockHidden: slot.arriving
                    }
                }
            }
        }
    }
}
