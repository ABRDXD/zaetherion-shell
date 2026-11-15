import QtQuick
import qs.view.cues
import qs.view.ui

// A montage row (Z29): a slanted −12° selection blade, the app's icon, its bold name and a faint mono description.
// The selected row's blade cuts in from the left. A blocked app (Z102) reads BLOCKED in the danger colour.
Item {
    id: root
    property var row: ({})
    property bool selected: false
    signal pointed()
    signal chosen()
    readonly property bool blocked: row?.blocked === true

    Cue {
        id: cut
        on: root.selected
        scope: root
        name: "launcher.row"
        enter: Motion.feedback
        exit: 0
    }
    // The blade's slanted ends lean by this much each way; it is inset by it so both stay in the row.
    readonly property real lean: Math.ceil(height * Math.abs(Design.shear) / 2)
    Item {
        anchors.fill: parent
        clip: true
        Rectangle {
            // The blade, sheared by Design.shear about its middle and cut in from the left by the cue.
            x: root.lean + (cut.value - 1) * parent.width
            width: parent.width - 2 * root.lean
            height: parent.height
            color: root.blocked ? Design.danger : Design.selected
            visible: cut.value > 0
            transform: Matrix4x4 {
                matrix: Qt.matrix4x4(1, Design.shear, 0, -Design.shear * root.height / 2, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
            }
        }
    }
    readonly property color ink: selected ? Design.islandFill : blocked ? Design.danger : root.row?.ready === false ? Design.faint : Design.ink
    Image {
        id: icon
        x: 3 * Design.baseline
        anchors.verticalCenter: parent.verticalCenter
        width: 24
        height: 24
        sourceSize: Qt.size(48, 48)
        source: root.row?.icon ?? ""
        visible: status === Image.Ready
        asynchronous: true
        smooth: true
    }
    MaterialSymbol {
        anchors.centerIn: icon
        visible: !icon.visible
        // Inline rows (Z195) have no icon file; each kind has its glyph.
        text: ({ calc: "calculate", convert: "straighten", command: "terminal", search: "travel_explore", verb: "bolt" })[root.row?.kind] ?? "apps"
        iconSize: 20
        color: root.ink
    }
    FText {
        id: name
        x: icon.x + icon.width + 3 * Design.baseline
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(implicitWidth, parent.width * 0.5)
        elide: Text.ElideRight
        text: root.row?.name ?? ""
        font.pixelSize: Design.control
        font.weight: Font.Bold
        color: root.ink
    }
    FText {
        anchors.left: name.right
        anchors.leftMargin: 3 * Design.baseline
        anchors.right: parent.right
        anchors.rightMargin: 3 * Design.baseline
        anchors.verticalCenter: parent.verticalCenter
        elide: Text.ElideRight
        technical: true
        text: root.blocked ? "> BLOCKED · SESSION" : (root.row?.description ?? "")
        font.pixelSize: Design.caption
        color: root.selected ? Qt.alpha(Design.islandFill, 0.7) : root.blocked ? Design.danger : Design.faint
    }
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onEntered: root.pointed()
        onClicked: root.chosen()
    }
}
