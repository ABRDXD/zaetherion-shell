import QtQuick

Canvas {
    id: glyph
    required property string mark
    property real batteryFraction: 0
    onBatteryFractionChanged: requestPaint()
    property color ink: "#f5ede0"
    onMarkChanged: requestPaint()
    onInkChanged: requestPaint()
    onPaint: {
        const c = getContext("2d");
        c.reset();
        c.scale(width / 24, height / 24);
        c.strokeStyle = ink;
        c.fillStyle = ink;
        c.lineWidth = 1.6;
        c.lineCap = "round";
        if (mark === "lock") {
            c.beginPath();
            c.arc(12, 10, 4.4, Math.PI, 2 * Math.PI);
            c.stroke();
            c.strokeRect(5, 10, 14, 10);
            c.fillRect(11, 13, 2, 4);
        } else if (mark === "battery") {
            c.strokeRect(2, 7, 18, 10);
            c.fillRect(4.5, 9.5, Math.round(13 * Math.max(0, Math.min(1, batteryFraction))), 5);
            c.fillRect(21, 10, 2, 4);
        } else if (mark === "power") {
            c.beginPath();
            c.arc(12, 13, 8, -1.0, 4.15);
            c.stroke();
            c.beginPath();
            c.moveTo(12, 2);
            c.lineTo(12, 12);
            c.stroke();
        } else if (mark === "enter") {
            c.beginPath();
            c.moveTo(20, 5);
            c.lineTo(20, 14);
            c.lineTo(5, 14);
            c.lineTo(10, 9);
            c.moveTo(5, 14);
            c.lineTo(10, 19);
            c.stroke();
        } else if (mark === "pause") {
            c.fillRect(7, 5, 3, 14);
            c.fillRect(14, 5, 3, 14);
        } else {
            if (mark === "previous") {
                c.translate(24, 0);
                c.scale(-1, 1);
            }
            c.beginPath();
            c.moveTo(5, 5);
            c.lineTo(15, 12);
            c.lineTo(5, 19);
            c.fill();
            if (mark !== "play")
                c.fillRect(16, 5, 2, 14);
        }
    }
}
