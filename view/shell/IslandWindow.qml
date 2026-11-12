import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.view.contract
import qs.core.client
import qs.view.ui

Scope {
    id: root
    required property HostAdapter host
    readonly property WorkspacesDomain workspaces: host.workspaces
    property string motionLevel: "all"
    property bool systemVoice: true
    signal openPanel(string room)
    signal togglePanel(string room)
    property bool docked: false
    readonly property var companionWindow: layer.active ? layer.item : null
    readonly property var islandRect: companionWindow?.islandRect ?? null
    signal openPower()
    signal ignite()
    signal notificationAction(string id, string action, string reply)
    property var workspaceIds: []
    property bool overdriveActive: false
    property CoreClient core: null
    property var startupNotice: null
    // Another surface (the docked panel) holds Exclusive keyboard focus and must let go first.
    property bool keyboardPeer: false
    property string arrangement: "framed"
    signal openLog(string url)
    function focusIsland(): void { companionWindow?.focusIsland(); }
    function openTray(itemId: string): void { companionWindow?.openTray(itemId); }
    required property ShellScreen output
    required property bool bottomEdge
    required property int edgeGap

    readonly property bool fullscreen: {
        if (!output || !workspaces.available) return false;
        const monitor = output.name;
        const active = workspaces.workspaces.filter(space => space.monitor === monitor && space.active);
        return workspaces.windows.some(window => window.fullscreen && window.monitor === monitor
            && active.some(space => space.id === window.workspaceId));
    }

    LazyLoader {
        id: layer
        active: root.output !== null && !root.fullscreen

        PanelWindow {
            id: panel
            property string trayItem: ""
            readonly property int draftLength: frame.draftLength
            readonly property string keyboardRequest: frame.keyboardRequest
            readonly property bool wantsKeyboard: frame.wantsKeyboard
            readonly property var islandRect: ({
                x: ((root.output?.width ?? frame.width) - frame.width) / 2,
                y: root.bottomEdge ? (root.output?.height ?? frame.height) - root.edgeGap - frame.height : root.edgeGap,
                width: frame.width, height: frame.height, edge: root.bottomEdge ? "bottom" : "top"
            })
            function focusIsland(): void { frame.enterKeyboard(); }
            function openTray(itemId: string): void {
                trayItem = itemId;
                root.host.tray.menu(itemId);
            }
            screen: root.output
            anchors.top: !root.bottomEdge
            anchors.bottom: root.bottomEdge
            // The surface never resizes: a layer surface resized every frame of a morph shows stretched frames (the
            // click-to-panel jitter). It spans the output and the deepest face; the island morphs inside it, the
            // mask keeps input to the island, and the transparent gap is inside it (a layer-shell margin would add
            // to the reserved zone).
            readonly property int deepest: 160
            implicitWidth: root.output?.width ?? frame.width
            implicitHeight: deepest + root.edgeGap
            exclusiveZone: frame.restHeight
            color: "transparent"
            WlrLayershell.namespace: "zaetherion-island"
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.keyboardFocus: frame.keyboardRequest === "exclusive" ? WlrKeyboardFocus.Exclusive
                : frame.keyboardRequest === "ondemand" ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
            mask: Region { item: frame }

            IslandSurface {
                id: frame
                host: root.host
                maximumWidth: root.output?.width ?? 420
                motionLevel: root.motionLevel
                systemVoice: root.systemVoice
                x: Math.round((panel.width - width) / 2)
                y: root.bottomEdge ? panel.height - root.edgeGap - height : root.edgeGap
                bottomEdge: root.bottomEdge
                notch: root.edgeGap === 0
                onOpenPanel: room => root.openPanel(room)
                onTogglePanel: room => root.togglePanel(room)
                docked: root.docked
                onOpenPower: root.openPower()
                workspaceIds: root.workspaceIds
                overdriveActive: root.overdriveActive
                core: root.core
                startupNotice: root.startupNotice
                keyboardPeer: root.keyboardPeer
                arrangement: root.arrangement
                onOpenLog: url => root.openLog(url)
                trayOpen: panel.trayItem !== ""
                onOpenTray: itemId => panel.openTray(itemId)
                onExpansionChanged: if (expansion) panel.trayItem = ""
                onIgnite: root.ignite()
                onNotificationAction: (id, action, reply) => root.notificationAction(id, action, reply)
            }

            HostLease {
                domain: root.host.tray
                feature: "menus"
                active: panel.trayItem !== ""
            }
            LazyLoader {
                active: panel.trayItem !== ""
                PopupWindow {
                    anchor.window: panel
                    anchor.rect: Qt.rect(Math.max(0, frame.x + frame.width - implicitWidth - 16),
                                         root.bottomEdge ? frame.y : frame.y + frame.height, implicitWidth, 0)
                    anchor.edges: root.bottomEdge ? Edges.Top : Edges.Bottom
                    anchor.gravity: root.bottomEdge ? Edges.Top : Edges.Bottom
                    grabFocus: true
                    visible: true
                    implicitWidth: menu.implicitWidth
                    implicitHeight: menu.implicitHeight
                    color: "transparent"
                    onVisibleChanged: if (!visible) panel.trayItem = ""
                    IslandTrayMenu {
                        id: menu
                        anchors.fill: parent
                        focus: true
                        entries: root.host.tray.menuEntries
                        onCloseRequested: panel.trayItem = ""
                        onChoose: entryId => root.host.tray.triggerMenuItem(panel.trayItem, entryId)
                    }
                }
            }
        }
    }
}
