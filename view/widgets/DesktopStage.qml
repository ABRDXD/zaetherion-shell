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
    // While the login lands into it (Z55) the clock is drawn by the login, then shown here.
    property bool clockHidden: false
    // A right-click on the bare desktop asks for the desktop menu there (Z86).
    signal menuRequested(point at)

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        onPressed: event => root.menuRequested(Qt.point(event.x, event.y))
    }

    DesktopClock {
        id: clockItem
        objectName: "desktopClock"
        x: root.clockRect.x
        y: root.clockRect.y
        width: root.clockRect.width
        height: root.clockRect.height
        rotation: root.pose.angle
        visible: !root.clockHidden && root.widgets?.shown !== false
        face: root.widgets?.face ?? ({})
    }
}
