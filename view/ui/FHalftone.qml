import QtQuick

Canvas {
    id: root
    property color ink: Qt.alpha(Design.muted, 0.2)
    property int pitch: 9
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onInkChanged: requestPaint()
    onPaint: {
        const ctx = getContext("2d");
        ctx.clearRect(0, 0, width, height);
        ctx.fillStyle = ink;
        for (let y = 4; y < height; y += pitch)
            for (let x = 4; x < width; x += pitch) {
                ctx.beginPath();
                ctx.arc(x, y, 0.8, 0, Math.PI * 2);
                ctx.fill();
            }
    }
}
