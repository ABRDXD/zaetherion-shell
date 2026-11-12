import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import qs.view.contract

// StatusNotifier items (the system tray). Items: { id, title, icon, status, hasMenu }. The menu of one item is read
// only while the `menus` lease is held, after menu(id) named it.
TrayDomain {
    id: root
    readonly property var raw: SystemTray.items.values
    property string menuItemId: ""
    readonly property var menuItem: menuItemId === "" ? null : raw.find(i => i.id === menuItemId) ?? null
    readonly property var statusNames: ({ [Status.Passive]: "passive", [Status.Active]: "active", [Status.NeedsAttention]: "attention" })

    available: true
    items: raw.map(i => ({ id: i.id, title: i.title || i.tooltipTitle || i.id, icon: i.icon ?? "",
        status: statusNames[i.status] ?? "active", hasMenu: i.hasMenu && !!i.menu }))
    menuEntries: holds("menus") && menuNode.item ? menuNode.item.snapshot : []

    // Created only while the lease is held on an item that has a menu; destroying it closes every submenu.
    Loader {
        id: menuNode
        active: root.holds("menus") && !!root.menuItem?.menu
        sourceComponent: QuickshellMenuNode { handle: root.menuItem.menu }
    }

    function menu(id: string): void { menuItemId = id; }
    function activate(id: string): void { raw.find(i => i.id === id)?.activate(); }
    function secondary(id: string): void { raw.find(i => i.id === id)?.secondaryActivate(); }
    function triggerMenuItem(id: string, entryId: string): void {
        if (id !== menuItemId || !menuNode.item) return;
        menuNode.item.triggerAt(entryId);
    }
}
