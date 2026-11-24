pragma ComponentBehavior: Bound
import QtQuick
import "DesktopGrid.js" as Grid

// What one screen's desktop holds: the clock at its pose on the 12-column grid (core/widgets.py's snapshot; the
// default pose until the core answers). The window around it is DesktopLayer (or a test's plain window).
Item {
    id: root
    property var widgets: null
    property string monitor: ""
    readonly property var pose: widgets?.monitors?.[monitor]?.clock ?? widgets?.defaults?.clock
        ?? ({ column: 2, span: 8, y: 0.42, angle: 0 })
    readonly property rect clockRect: {
        const r = Grid.rect(pose, width, height);
        return Qt.rect(r.x, r.y, r.width, r.height);
    }
    readonly property alias clock: clockItem

    DesktopClock {
        id: clockItem
        objectName: "desktopClock"
        x: root.clockRect.x
        y: root.clockRect.y
        width: root.clockRect.width
        height: root.clockRect.height
        rotation: root.pose.angle
        face: root.widgets?.face ?? ({})
    }
}
