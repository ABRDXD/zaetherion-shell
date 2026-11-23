// Workspace: { id, name, monitor, active, windowCount }.
// Window: { id, title, appId, workspaceId, monitor, x, y, width, height, floating, fullscreen, focused }.
// Monitor: { name, x, y, width, height, scale, reservedTop, reservedBottom }; geometry in logical pixels
// except width/height, which are the mode size (divide by scale).
HostDomain {
    property string focusedScreen: ""
    property string activeId: ""
    property var workspaces: []
    property var windows: []
    property var monitors: []

    function switchTo(workspaceId: string) { record("switchTo", [workspaceId]); }
    function focusWindow(windowId: string) { record("focusWindow", [windowId]); }
    function moveWindow(windowId: string, workspaceId: string) { record("moveWindow", [windowId, workspaceId]); }
    // What a capture of this window reads from (opaque to the view), or null where the host can't capture it.
    function thumbnailSource(windowId: string) { return null; }
}
