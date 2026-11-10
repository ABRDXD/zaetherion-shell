import QtQuick
import qs.view.ui
import "TemporalMath.js" as Field

// Silent contour plate: event/whole-second driven, with no clock or animation of its own.
Canvas {
    id: root
    property var sources: []
    property real remainingFraction: 1
    property int painted: 0
    property color ink: Design.ink
    property color signal: Design.accent
    onInkChanged: requestPaint()
    onSignalChanged: requestPaint()
    onSourcesChanged: requestPaint()
    onRemainingFractionChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    Connections { target: Design; function onSourceChanged() { root.requestPaint(); } }
    onPaint: {
        const c = getContext("2d"); c.reset();
        const segments = Field.segments(width, height, sources, remainingFraction, 60);
        for (let major = 0; major < 2; major++) {
            c.strokeStyle = Qt.alpha(major ? Design.accent : Design.ink, major ? 0.5 : 0.15);
            c.lineWidth = major ? 1.4 : 0.65;
            c.beginPath();
            for (const s of segments) {
                if ((Math.abs(s[2] % 300) < 0.1 ? 1 : 0) !== major) continue;
                c.moveTo(s[0][0],s[0][1]); c.lineTo(s[1][0],s[1][1]);
            }
            c.stroke();
        }
        // One 78° discontinuity. Geometry alone deforms; readouts are siblings above it.
        const aspect = width / Math.max(1,height);
        c.strokeStyle = Design.accent; c.lineWidth = 2;
        c.beginPath(); c.moveTo(Field.seam(0,aspect)*height,0); c.lineTo(Field.seam(1,aspect)*height,height); c.stroke();
        painted++;
    }
}
