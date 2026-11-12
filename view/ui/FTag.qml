import QtQuick

// The sheet's inverted tag (DESIGN_SYSTEM.md "ink tag"): a plane with both sides at 78° that carries a
// name or a short label in the plane's own text colour. Ink by default; signal for an alarm.
Item {
    id: root
    property string text: ""
    property string symbol: ""
    property string role: "ink"     // ink | signal
    property bool technical: true
    readonly property color textColor: plane.textColor
    readonly property real run: height * Math.tan(12 * Math.PI / 180)
    implicitHeight: Design.baseline * 5
    readonly property real glyphWidth: symbol !== "" ? Design.control + Design.baseline : 0
    readonly property real padding: 2 * run + 2 * Design.baseline
    implicitWidth: Math.ceil(label.implicitWidth + glyphWidth + padding)

    Plane {
        id: plane
        anchors.fill: parent
        role: root.role
        slant: 3
    }
    Row {
        id: row
        anchors.centerIn: parent
        spacing: Design.baseline
        MaterialSymbol {
            visible: root.symbol !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: root.symbol
            iconSize: Design.control
            color: root.textColor
        }
        FText {
            id: label
            visible: root.text !== ""
            anchors.verticalCenter: parent.verticalCenter
            // Narrower than its name, the tag elides; it never sizes itself from the row.
            width: Math.max(0, Math.min(implicitWidth, root.width - root.glyphWidth - root.padding))
            text: root.text
            technical: root.technical
            font.weight: Font.Bold
            color: root.textColor
        }
    }
}
