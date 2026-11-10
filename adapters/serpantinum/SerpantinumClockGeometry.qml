import QtQuick
import qs.view.contract

// The hook reports the exact clock rect (M5); otherwise estimate from the host's bar settings.
// Rects are in the screen's own logical coordinates, as the hook reports them (bar margins added).
ClockGeometryDomain {
    id: root
    required property var settings
    required property WorkspacesDomain workspaces
    readonly property var bar: settings.values.bar ?? {}
    readonly property int estimatedWidth: 160
    property var hookRects: ({})
    available: true
    function rectFor(screen: string): var {
        if (hookRects[screen]) return hookRects[screen];
        const m = workspaces.monitors.find(m => m.name === screen) ?? workspaces.monitors[0];
        const height = Number(bar.height) || 40;
        const edge = bar.position === "bottom" ? "bottom" : "top";
        if (!m) return { x: 0, y: 0, width: estimatedWidth, height: height, edge: edge, exact: false };
        const width = m.width / m.scale, screenHeight = m.height / m.scale;
        return { x: Math.round((width - estimatedWidth) / 2), y: edge === "top" ? 0 : Math.round(screenHeight - height),
            width: estimatedWidth, height: height, edge: edge, exact: false };
    }
    function setHookRect(screen: string, x: int, y: int, width: int, height: int) {
        if (width <= 0 || height <= 0) return;
        const m = workspaces.monitors.find(m => m.name === screen);
        const edge = m && y > m.height / m.scale / 2 ? "bottom" : "top";
        hookRects = Object.assign({}, hookRects, { [screen]: { x: x, y: y, width: width, height: height, edge: edge, exact: true } });
    }
}
