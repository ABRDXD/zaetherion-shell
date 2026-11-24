pragma ComponentBehavior: Bound
import QtQuick

// The Register title wedge, carried all the way to the clock's upper edge (tools/login-clock-study, Astra,
// owner's pick 23 Nov). At rest it is the Day index clock's Æ stamp; the login (Z55) seats its four slices.
// The four strips share one coordinate system from full sheet to small stamp.
Item {
    id: mark
    required property real progress
    required property int line
    property color paper: "#f2efdf"
    readonly property int glyphSize: 345 // the wedge's own 425 px sheet; the caller's scale applies
    Item {
        width: 425
        height: 306
        transformOrigin: Item.TopLeft
        scale: mark.width / width
        Canvas {
            anchors.fill: parent
            property color fill: mark.paper
            onFillChanged: requestPaint()
            onPaint: {
                const c = getContext("2d");
                c.fillStyle = fill;
                c.beginPath();
                c.moveTo(66, 0); c.lineTo(width, 0); c.lineTo(width, height);
                c.lineTo(1, height); c.closePath(); c.fill();
            }
        }
        FontMetrics {
            id: type
            font.family: "DejaVu Sans"
            font.weight: Font.Black
            font.pixelSize: mark.glyphSize
        }
        Item {
            id: impression
            x: 78; y: 26; width: 347; height: 254
            // Measured again when the font settles (its size is a binding, applied after this first runs).
            readonly property rect bounds: type.font.pixelSize > 0 ? type.tightBoundingRect("Æ") : Qt.rect(0, 0, 0, 0)
            clip: true
            Repeater {
                model: 4
                Item {
                    id: slice
                    required property int index
                    readonly property real seated: Math.max(0, Math.min(1, mark.progress * 4 - index))
                    y: Math.round(impression.bounds.height * index / 4)
                    height: Math.round(impression.bounds.height * (index + 1) / 4) - y
                    width: impression.width
                    clip: true
                    Text {
                        x: -impression.bounds.x + (1 - slice.seated) * 64
                        y: -baselineOffset - impression.bounds.y - slice.y
                        text: "Æ"
                        font: type.font
                        color: slice.index > mark.line ? "#cac7bb" : "#20232a"
                    }
                }
            }
        }
    }
}
