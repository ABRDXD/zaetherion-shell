import qs.view.cues
import qs.view.ui
import QtQuick

// The ballistic command line (docs/OVERDRIVE_IDEAS.md #59): in Overdrive the candidates for what you are typing fly out
// from the caret along the house's -12°, each on its own plate. Type fast and the ray stretches out; hesitate and it
// falls short. It reads the command line's own hint; only the timing of keys is measured, inside this item.
Item {
    id: root
    required property var line
    // Where the ray starts, in this item's coordinates.
    property real originX: 0
    property real originY: 0
    readonly property var candidates: line?.hint?.candidates ?? []
    property real interval: 400
    property double lastKey: 0
    readonly property real reach: 16 + 150 * (1 - Math.min(1, interval / 420))
    Connections {
        target: root.line
        function onTextChanged() {
            const now = Date.now();
            if (root.lastKey > 0)
                root.interval = root.interval * 0.6 + Math.min(1000, now - root.lastKey) * 0.4;
            root.lastKey = now;
        }
    }
    Repeater {
        model: root.candidates.slice(0, 8)
        Plane {
            id: plate
            required property var modelData
            required property int index
            readonly property real along: 26 + (root.reach + 34) * index
            x: root.originX + along * 0.9781
            y: root.originY + along * 0.2079 + index * 22
            width: label.implicitWidth + 22
            height: 22
            role: index === 0 ? "signal" : "ink"
            slant: 3
            backing: true
            opacity: Motion.drive * (1 - index * 0.08)
            FText {
                id: label
                anchors.centerIn: parent
                text: plate.modelData.name
                technical: true
                font.capitalization: Font.MixedCase
                color: plate.textColor
            }
        }
    }
}
