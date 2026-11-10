import qs.view.cues
import qs.view.ui
import QtQuick

// Typeset teleport (docs/OVERDRIVE_IDEAS.md #37): during a room switch the facts that belong to no room (the time, the machine's load, what's unread) hold still at one spot
// over the field, and the whole page flies past behind them. Continuity belongs to the information, not the sheet.
Item {
    id: root
    property real t: 0
    property bool switching: false
    property string clock: ""
    // Percent, or a negative number when the machine isn't being sampled.
    property real load: -1
    property int unread: 0
    // Up quickly, and gone only as the room lands, so the facts are the last thing left of the journey.
    readonly property real envelope: switching ? Math.min(1, t / 0.08) * Math.min(1, (1 - t) / 0.08) : 0
    readonly property var facts: {
        const out = [{ label: "LOCAL", value: root.clock }];
        if (root.load >= 0)
            out.push({ label: "LOAD", value: Math.round(root.load) + "%" });
        out.push({ label: "UNREAD", value: String(root.unread) });
        return out;
    }
    visible: envelope > 0
    opacity: envelope * Motion.drive
    // On its own plate: the panes that fly past are any colour at all, the theme's lightest included.
    Rectangle {
        anchors.fill: strip
        anchors.margins: -10
        color: Design.background
        border.width: 1
        border.color: Design.line
    }
    Row {
        id: strip
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: 34
        anchors.topMargin: 26
        spacing: 26
        Repeater {
            model: root.facts
            Column {
                required property var modelData
                spacing: 1
                FText {
                    text: modelData.label
                    technical: true
                    font.pixelSize: Design.caption
                    color: Design.muted
                }
                FText {
                    text: modelData.value
                    technical: true
                    font.pixelSize: Design.readout
                    font.weight: Font.Black
                    color: Design.ink
                }
            }
        }
    }
}
