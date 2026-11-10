import qs.view.cues
import qs.view.ui
import QtQuick
import QtQuick.Shapes

// The ruler (docs/OVERDRIVE_IDEAS.md #61): in Overdrive the footer rule has a station for each room. A quick stroke
// along it (at least 60 px in under half a second) goes to the station where it ends. The stroke stays for 400 ms as
// a drafting mark, with the angle it was read at and how straight it was. A slow drag does nothing.
Item {
    id: root
    // Where the rule runs, in this item's coordinates, and the room ids in order.
    property real ruleY: 0
    property var rooms: []
    signal chosen(string id)
    property var points: []
    property double started: 0
    property bool drawing: false
    property string reading: ""
    function station(x) { return Math.max(0, Math.min(rooms.length - 1, Math.floor(x / Math.max(1, width) * rooms.length))); }
    function finish() {
        drawing = false;
        const first = points[0], last = points[points.length - 1];
        if (!first || !last)
            return;
        let path = 0;
        for (let i = 1; i < points.length; i++)
            path += Math.hypot(points[i].x - points[i - 1].x, points[i].y - points[i - 1].y);
        const chord = Math.hypot(last.x - first.x, last.y - first.y);
        if (chord < 60 || Date.now() - started > 500) {
            points = [];
            return;
        }
        const angle = Math.round(Math.atan2(first.y - last.y, last.x - first.x) * 180 / Math.PI);
        reading = String(angle).padStart(3, "0") + "°  ·  " + (chord / Math.max(1, path)).toFixed(2) + "  ·  " + String(station(last.x)).padStart(2, "0");
        fossil.restart();
        root.chosen(rooms[station(last.x)]);
    }
    // The stations, faint, while a stroke is in the air.
    Repeater {
        model: root.drawing ? root.rooms.length : 0
        FText {
            required property int index
            x: (index + 0.5) * root.width / root.rooms.length - implicitWidth / 2
            y: root.ruleY - 16
            text: String(index).padStart(2, "0")
            technical: true
            font.pixelSize: Design.caption
            color: index === root.station(root.points[root.points.length - 1]?.x ?? -1) ? Design.accent : Design.faint
        }
    }
    // The fossil: the stroke as drawn, with its reading.
    Shape {
        visible: root.points.length > 1
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: Design.accent
            strokeWidth: 1.5
            fillColor: "transparent"
            PathPolyline { path: root.points.map(p => Qt.point(p.x, p.y)) }
        }
    }
    FText {
        visible: fossil.running
        x: Math.max(0, Math.min(root.width - implicitWidth, (root.points[root.points.length - 1]?.x ?? 0) - implicitWidth / 2))
        y: root.ruleY - 34
        text: root.reading
        technical: true
        font.pixelSize: Design.caption
        color: Design.accent
    }
    Timer {
        id: fossil
        interval: 400
        onTriggered: root.points = []
    }
    MouseArea {
        y: root.ruleY - 8
        width: parent.width
        height: 16
        cursorShape: Qt.SplitHCursor
        onPressed: mouse => {
            fossil.stop();
            root.points = [Qt.point(mouse.x, y + mouse.y)];
            root.started = Date.now();
            root.drawing = true;
        }
        onPositionChanged: mouse => { if (root.drawing) root.points = [...root.points.slice(-60), Qt.point(mouse.x, y + mouse.y)]; }
        onReleased: root.finish()
        onCanceled: { root.drawing = false; root.points = []; }
    }
}
