import qs.view.ui
import QtQuick
import "Geology.js" as G

// The battery ledger (atlas #22, docs/OVERDRIVE.md §28), on Devices' power row in place of its plain hairline: each
// weather report (core/weather.py) is an entry along the line, as wide as the time it covers, hanging below the line by
// the share of the battery it spent, or standing above it when it charged. The battery as an account. Static.
Item {
    id: root
    property var entries: []
    implicitHeight: 16
    readonly property real lineY: 5
    readonly property var book: G.ledger(entries, Math.max(0, width - 6))
    Hairline { y: root.lineY - 2; width: root.width; node: 3 }
    Repeater {
        model: root.book
        Item {
            required property var modelData
            x: modelData.x
            width: modelData.w
            Rectangle { x: 0; y: root.lineY - 3; width: 1; height: 5; color: Design.line }
            Rectangle {
                visible: modelData.depth > 0.01
                x: 1
                width: Math.max(1, parent.width - 2)
                height: Math.max(1, modelData.depth * (modelData.credit ? root.lineY - 1 : root.height - root.lineY - 1))
                y: modelData.credit ? root.lineY - height : root.lineY + 1
                color: modelData.credit ? Design.accent : Design.muted
                opacity: 0.55
            }
        }
    }
}
