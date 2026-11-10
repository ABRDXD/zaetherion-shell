import QtQuick
import QtQuick.Controls
import qs.view.contract
import qs.view.shell
import qs.view.ui
import qs.view.cues

Item {
    id: root
    required property HostAdapter host
    required property ShellContext shell
    property var historyOverride: null
    readonly property var wm: host.workspaces
    readonly property bool narrow: width < 730
    readonly property int current: Number(wm.activeId) || 1
    property int looking: 0
    readonly property int inspected: looking || current
    readonly property var history: historyOverride || feed.snapshot
    readonly property int count: Math.max(7, Math.min(12, Config.options.bar.workspaces.shown))
    readonly property var nodes: history?.nodes?.length ? history.nodes.filter(n => String(n.workspace) === String(inspected))
        : wm.windows.filter(w => Number(w.workspaceId) === inspected).map((w, i) => ({id: i + 1, address: String(w.id).replace(/^0x/, ""), app: w.appId, workspace: String(w.workspaceId), parent: null, closed: null}))
    readonly property int scars: nodes.filter(n => n.closed !== null).length
    GenealogyFeed { id: feed; visible: root.visible && !root.historyOverride }
    function windowsOn(number) { return wm.windows.filter(w => Number(w.workspaceId) === number).length; }

    FText {
        id: heading; text: "FORMATION"; headline: true; font.pixelSize: Design.headline
        font.weight: Font.Black; font.letterSpacing: -2
    }
    FText {
        anchors.left: heading.right; anchors.leftMargin: 16; anchors.bottom: heading.bottom; anchors.bottomMargin: 8
        text: "LAUNCH ━  /  FOCUS ┄"; technical: true; color: Design.muted; visible: !root.narrow
    }
    Hairline { id: rule; anchors.top: heading.bottom; anchors.topMargin: 8; width: parent.width; node: 4 }
    Column {
        id: stack
        anchors.right: parent.right; anchors.top: rule.bottom; anchors.topMargin: 20
        width: root.narrow ? 130 : 178; spacing: 3
        FText { text: "DESK / " + String(root.inspected).padStart(2, "0"); technical: true; color: Design.muted; bottomPadding: 12 }
        Repeater {
            model: root.count
            WorkspaceTab {
                required property int index
                width: stack.width; number: index + 1; windows: root.windowsOn(number)
                current: root.current === number; inspected: root.inspected === number
                remembered: !!root.history?.memories?.[String(number)]
                onLook: on => root.looking = on ? number : root.looking === number ? 0 : root.looking
                onClicked: root.wm.switchTo(String(number))
            }
        }
        FText {
            width: parent.width; topPadding: 14; text: "Branches record adjacency.\nNot process ancestry."
            aside: true; wrapMode: Text.Wrap; color: Design.muted
        }
    }
    Item {
        id: margin
        anchors.right: stack.left; anchors.rightMargin: 24; width: root.narrow ? 28 : 58
        anchors.top: rule.bottom; anchors.topMargin: 50; anchors.bottom: footer.top; anchors.bottomMargin: 28
        GenealogyTrace { anchors.fill: parent; history: root.history?.focus ?? []; at: root.history?.at ?? 0 }
        FText { anchors.bottom: parent.top; anchors.bottomMargin: 10; text: "FOCUS"; technical: true; color: Design.muted }
        Rectangle { width: 1; height: parent.height; color: Design.line; opacity: 0.4 }
    }
    GenealogyTree {
        id: tree
        anchors.left: parent.left; anchors.right: margin.left; anchors.rightMargin: 20
        anchors.top: rule.bottom; anchors.topMargin: 12; anchors.bottom: footer.top; anchors.bottomMargin: 12
        focusHistory: root.history?.focus ?? []
        nodes: root.nodes; windows: root.wm.windows; active: root.history?.active ?? ""
        witnessed: !!root.history?.nodes?.length
        memory: root.history?.memories?.[String(root.inspected)] ?? null
        onFocusWindow: address => root.wm.focusWindow(address)
        FText { anchors.centerIn: parent; visible: !root.nodes.length && !tree.memory; text: "NO BRANCHES YET"; technical: true; color: Design.muted }
    }
    Row {
        id: footer; anchors.bottom: parent.bottom; width: parent.width; spacing: 20
        FText { text: String(root.nodes.length - root.scars).padStart(2, "0") + " ALIVE"; technical: true }
        FText { text: String(root.scars).padStart(2, "0") + " SCARS"; technical: true; color: Design.muted }
        FText { text: root.history?.available ? "SESSION MEMORY / 24 H MAX" : "LIVE COMPOSITION / HISTORY OFFLINE"; technical: true; color: Design.faint; visible: !root.narrow }
    }
}
