pragma ComponentBehavior: Bound
import QtQuick

Item {
    id: gauge
    required property EditPose placement
    required property string tool
    required property bool fluid
    readonly property string family: fluid ? "Noto Sans" : "DejaVu Sans Mono"
    readonly property bool rotationMode: tool === "Rotate"
    readonly property int minimum: rotationMode ? -180 : tool === "Move" ? 1 : 3
    readonly property int maximum: rotationMode ? 180 : tool === "Move" ? 13 - placement.span : 12 - placement.column
    readonly property int divisions: rotationMode ? 12 : maximum - minimum
    readonly property int reading: rotationMode ? placement.angle : tool === "Move" ? placement.column + 1 : placement.span
    readonly property real value: (reading - minimum) / Math.max(1, maximum - minimum)
    readonly property int inset: 7
    readonly property real run: width - 2 * inset

    function setAt(x) {
        const ratio = Math.max(0, Math.min(1, (x - inset) / run));
        const target = minimum + Math.round(ratio * (maximum - minimum));
        if (rotationMode) placement.angle = target;
        else if (tool === "Move") placement.column = target - 1;
        else placement.span = target;
    }
    Rectangle { x: gauge.inset; y: 25; width: gauge.run; height: 1; color: "#777479" }
    Repeater {
        model: gauge.divisions + 1
        Rectangle {
            required property int index
            x: gauge.inset + gauge.run * index / Math.max(1, gauge.divisions)
            y: 26; width: 1
            height: index % 3 === 0 || index === gauge.divisions ? 12 : 7
            color: "#777479"
        }
    }
    Rectangle {
        x: gauge.inset + gauge.value * gauge.run - 3; y: 10
        width: 6; height: 21; radius: gauge.fluid ? 3 : 0; color: "#332f40"
    }
    Repeater {
        model: 2
        Text {
            required property int index
            visible: index === 0 || gauge.minimum < gauge.maximum
            y: 43; x: index ? gauge.width - width : 0
            text: gauge.rotationMode ? (index ? "+180°" : "−180°") : String(index ? gauge.maximum : gauge.minimum)
            font.family: gauge.family; font.pixelSize: 12; color: "#48454e"
        }
    }
    MouseArea {
        objectName: "scaleInput"
        anchors.fill: parent
        cursorShape: Qt.SizeHorCursor
        onPressed: event => gauge.setAt(event.x)
        onPositionChanged: event => { if (pressed) gauge.setAt(event.x); }
    }
}
