import qs.view.cues
import qs.view.ui
import QtQuick
import "Photocopy.js" as P

// Photocopy generations (docs/OVERDRIVE.md §49; B's own idea), the Stratum `clips.copy.<row>` inside a clip's preview,
// under it: the generation its place in the history makes it. The preview's own ink thins (a Binding, restored on
// release), a second impression slips out of register beneath it, and toner speckle gathers over it.
Item {
    id: root
    required property Text target
    property int index: 0
    property string seed: ""
    readonly property int gen: P.generation(index)
    readonly property var slip: P.slip(gen)
    Binding { target: root.target; property: "opacity"; value: 1 - (1 - P.ink(root.gen)) * Motion.drive }
    // The slipped impression, under the text.
    Text {
        x: root.slip.x
        y: root.slip.y
        width: root.target.width
        text: root.target.text
        font: root.target.font
        wrapMode: root.target.wrapMode
        maximumLineCount: root.target.maximumLineCount
        elide: root.target.elide
        textFormat: Text.PlainText
        color: root.target.color
        opacity: root.slip.alpha * Motion.drive
        visible: root.gen > 0
    }
    // Toner speckle, in the gaps of the text (the layer lies under it).
    Canvas {
        anchors.fill: parent
        z: 2
        visible: root.gen > 0
        opacity: Motion.drive
        renderTarget: Canvas.Image
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            ctx.fillStyle = Qt.alpha(Design.ink, 0.35);
            for (const p of P.speckle(root.seed, root.gen, width, height))
                ctx.fillRect(p.x, p.y, p.r, p.r);
        }
    }
}
