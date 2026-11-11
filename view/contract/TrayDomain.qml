// Items: { id, title, icon, status, hasMenu }. The adapter owns menu handles.
HostDomain {
    property var items: []
    // Plain menu snapshot for the item requested with menu(id), held under the menus lease.
    property var menuEntries: []
    function triggerMenuItem(id: string, entryId: string): void { record("triggerMenuItem", [id, entryId]); }
    function activate(id: string): void { record("activate", [id]); }
    function secondary(id: string): void { record("secondary", [id]); }
    function menu(id: string): void { record("menu", [id]); }
}
