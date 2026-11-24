import QtQuick
// From tools/widget-study (Astra, approved 23 Nov), unchanged.

// Keep the artwork upright inside a moving 78° clipping edge. At full travel
// the clip switches off, leaving the complete face at its original coordinates.
Item {
    id: reveal
    property real amount: 1
    property bool fromRight: false
    default property alias content: carrier.data
    readonly property real run: width + height * 0.21255656

    Item {
        id: gate
        x: reveal.fromRight ? reveal.run * (1 - reveal.amount) : 0
        width: reveal.run * reveal.amount
        height: reveal.height
        clip: reveal.amount < 1
        visible: reveal.amount > 0
        transform: Matrix4x4 {
            matrix: Qt.matrix4x4(1,-0.21255656,0,0, 0,1,0,0, 0,0,1,0, 0,0,0,1)
        }
        Item {
            id: carrier
            x: -gate.x
            width: reveal.width
            height: reveal.height
            transform: Matrix4x4 {
                matrix: Qt.matrix4x4(1,0.21255656,0,0, 0,1,0,0, 0,0,1,0, 0,0,0,1)
            }
        }
    }
}
