import qs.view.ui
import QtQuick
import QtQuick.Shapes

// A clip kind's editorial mark (MIME taxonomy, atlas #31, docs/OVERDRIVE.md §27): text is underlined, a link is a forked
// stalk, an image a boxed corner, a path a stair, code a pair of brackets at the house angle, a number a tally struck
// through, a colour its swatch. Static; nothing of the clip but its kind (and a colour's own value) is drawn.
Item {
    id: root
    property string kind: "TEXT"
    property string swatch: ""
    readonly property color swatchColor: {
        if (swatch.startsWith("#")) return swatch;
        const channels = /^rgba?\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)(?:\s*,\s*(\d*\.?\d+))?\s*\)$/i.exec(swatch);
        return channels ? Qt.rgba(Math.min(255, +channels[1]) / 255, Math.min(255, +channels[2]) / 255,
                                  Math.min(255, +channels[3]) / 255, Math.min(1, +(channels[4] ?? 1))) : "transparent";
    }
    property color ink: Design.faint
    implicitWidth: 26
    implicitHeight: 14
    readonly property var paths: ({
        TEXT: [[0, 13, 22, 13]],
        LINK: [[6, 14, 6, 7], [6, 7, 2, 0], [6, 7, 11, 0]],
        IMAGE: [[0, 5, 0, 0], [0, 0, 5, 0], [21, 14, 26, 14], [26, 14, 26, 9]],
        PATH: [[0, 14, 0, 10], [0, 10, 6, 10], [6, 10, 6, 5], [6, 5, 12, 5], [12, 5, 12, 0], [12, 0, 18, 0]],
        CODE: [[6, 1, 2, 7], [2, 7, 6, 13], [14, 1, 18, 7], [18, 7, 14, 13]],
        NUMBER: [[2, 2, 2, 12], [6, 2, 6, 12], [10, 2, 10, 12], [14, 2, 14, 12], [0, 11, 17, 3]]
    })
    Shape {
        anchors.fill: parent
        visible: root.kind !== "COLOUR"
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: root.ink
            strokeWidth: 1
            fillColor: "transparent"
            PathMultiline {
                paths: (root.paths[root.kind] ?? root.paths.TEXT).map(s => [Qt.point(s[0], s[1]), Qt.point(s[2], s[3])])
            }
        }
    }
    Rectangle {
        visible: root.kind === "COLOUR"
        y: 2
        width: 10
        height: 10
        color: root.swatchColor
        border.width: 1
        border.color: root.ink
    }
}
