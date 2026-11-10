import QtQuick

Item {
    id: root
    property var values: []
    property color ink: Design.accent
    property int capacity: 60
    property bool unavailable: false
    onValuesChanged: graph.requestPaint()
    onInkChanged: graph.requestPaint()
    Canvas {
        id: graph
        anchors.fill: parent
        anchors.rightMargin: 32
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            const top = 3, bottom = height - 3, range = bottom - top;
            ctx.strokeStyle = Qt.alpha(Design.muted, 0.22);
            ctx.lineWidth = 1;
            for (let i = 0; i <= 4; i++) {
                const y = top + range * i / 4;
                ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(width, y); ctx.stroke();
            }
            const data = root.values.slice(-root.capacity);
            if (!data.length) return;
            // Fixed time and 0–100 scales. Both paths share exactly these points.
            const points = data.map((v, i) => ({
                x: width * (root.capacity - data.length + i) / (root.capacity - 1),
                y: bottom - Math.max(0, Math.min(1, v)) * range
            }));
            ctx.beginPath(); ctx.moveTo(points[0].x, bottom);
            for (const p of points) ctx.lineTo(p.x, p.y);
            ctx.lineTo(points[points.length - 1].x, bottom); ctx.closePath();
            ctx.fillStyle = Qt.alpha(root.ink, 0.14); ctx.fill();
            ctx.beginPath(); ctx.moveTo(points[0].x, points[0].y);
            for (const p of points.slice(1)) ctx.lineTo(p.x, p.y);
            ctx.lineWidth = 2; ctx.lineJoin = "round"; ctx.strokeStyle = root.ink; ctx.stroke();
            const last = points[points.length - 1];
            ctx.beginPath(); ctx.arc(last.x - 1, last.y, 2.5, 0, Math.PI * 2);
            ctx.fillStyle = root.ink; ctx.fill();
        }
    }
    FText {
        anchors.left: parent.left
        anchors.leftMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        visible: root.values.length < root.capacity
        text: root.unavailable ? "UNAVAILABLE" : "SAMPLING... " + root.values.length + "/" + root.capacity
        technical: true
        color: Design.faint
    }
    Repeater {
        model: [100, 50, 0]
        FText {
            required property int index
            required property int modelData
            anchors.right: parent.right
            y: index * (root.height - height) / 2
            text: modelData
            technical: true
            font.pixelSize: Design.caption
            color: Design.faint
        }
    }
}
