import qs.view.ui
import qs.view.cues
import QtQuick
import QtQuick.Controls

// One window of the inspected desk, as a slanted blade under the Workspaces orbit (Z209): its app large, its
// title small. The selected window is inverted ink, and the room's actions (focus, move) act on it. A click
// selects it; a second click on the selected one focuses it.
AbstractButton {
    id: root
    required property string app
    required property string title
    property bool selected: false
    implicitHeight: 88
    hoverEnabled: true
    focusPolicy: Qt.StrongFocus
    Accessible.name: app + ", " + title + (selected ? ", selected" : "")
    onClicked: Feedback.play("ui.click")
    // Wrapped in an Item: a bare Plane sets its own z and would draw over the text.
    background: Item {
        Plane {
            id: plane
            anchors.fill: parent
            role: root.selected ? "ink" : root.hovered || root.activeFocus ? "paper" : "clear"
            backing: true
            slant: 3
        }
    }
    contentItem: Item {
        clip: true
        FText {
            id: name
            x: 26
            y: 12
            width: parent.width - 48
            text: root.app
            headline: true
            sheared: true
            elide: Text.ElideRight
            font.pixelSize: Design.figure
            font.weight: Font.Black
            color: plane.textColor
        }
        FText {
            x: 22
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 12
            width: parent.width - 44
            text: root.title
            technical: true
            elide: Text.ElideRight
            color: root.selected ? plane.textColor : Design.muted
        }
    }
}
