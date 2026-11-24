pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

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
    // Each open desktop menu or editor (DesktopSheet), for tests.
    readonly property var sheets: Array.from(variants.instances).map(slot => slot.sheet).filter(Boolean)
    // Wallpaper, Theme and Settings from the desktop menu: the shell opens its Settings at that section.
    signal openSettings(string section)

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
                    }
                }
            }
        }
    }
}
