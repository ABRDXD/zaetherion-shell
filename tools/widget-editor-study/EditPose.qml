import QtQml

// Gesture coordinates are in the unrotated desktop, even when the face turns.
// Values and limits are local to this mock.
QtObject {
    id: pose
    required property real step
    required property real leftInset
    required property real canvasHeight
    property int column: 2
    property int span: 8
    property real middleY: canvasHeight * .42
    property int angle: 0
    readonly property real left: leftInset + column * step
    readonly property real faceWidth: span * step
    readonly property real faceHeight: faceWidth * 209 / 780
    property string gesture: ""
    property point origin
    property int firstColumn
    property int firstSpan
    property int firstAngle
    property real firstY

    function bearing(point) {
        return Math.atan2(point.y - firstY, point.x - (left + faceWidth / 2)) * 180 / Math.PI;
    }
    function begin(kind, point) {
        origin = point;
        firstColumn = column; firstSpan = span; firstAngle = angle; firstY = middleY;
        gesture = kind;
    }
    function track(point) {
        const dx = point.x - origin.x;
        const dy = point.y - origin.y;
        if (gesture === "Move") {
            column = Math.max(0, Math.min(12 - span, firstColumn + Math.round(dx / step)));
            middleY = Math.max(faceHeight / 2, Math.min(canvasHeight - faceHeight / 2, firstY + dy));
        } else if (gesture === "Resize") {
            const rad = firstAngle * Math.PI / 180;
            const advance = dx * Math.cos(rad) + dy * Math.sin(rad);
            span = Math.max(3, Math.min(12 - column, firstSpan + Math.round(advance / step)));
        } else if (gesture === "Rotate") {
            const turn = Math.round(firstAngle + bearing(point) - bearing(origin));
            angle = ((turn + 540) % 360) - 180;
        }
    }
}
