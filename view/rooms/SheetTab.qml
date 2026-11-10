import qs.view.ui
import QtQuick
import QtQuick.Controls

// A tab on the sheet (MONTAGE §4.4, the YoRHa selection): at rest a plain technical label; selected,
// an inverted ink plane with 78° edges and a thin rule above and below. `count` is an optional
// figure set after the label. Room-local until view/ui has its own inversion (Claude A, M6).
AbstractButton {
    id: root
    property string label: ""
    property string count: ""
    property bool selected: false
    property bool large: false   // the head's tab: the name in Black at readout size
    readonly property color inkColor: selected ? plane.textColor : hovered ? Design.ink : Design.muted
    implicitHeight: large ? 34 : 28
    implicitWidth: row.implicitWidth + (large ? 40 : 26)
    hoverEnabled: true
    Accessible.name: label + (count ? " " + count : "")
    Accessible.role: Accessible.PageTab
    onClicked: Feedback.play("ui.click")
    background: Item {
        Plane {
            id: plane
            anchors.fill: parent
            anchors.topMargin: 4
            anchors.bottomMargin: 4
            role: root.selected ? "ink" : root.hovered ? "paper" : "clear"
            slant: 3
        }
        Rectangle { visible: root.selected; width: parent.width; height: 1; color: Design.ink }
        Rectangle { visible: root.selected; y: parent.height - 1; width: parent.width; height: 1; color: Design.ink }
        Rectangle {
            // Keyboard focus without the reticle still shows: an outline rule under the label.
            visible: root.activeFocus && !root.selected
            x: 10
            y: parent.height - 6
            width: parent.width - 20
            height: 1
            color: Design.ink
        }
    }
    contentItem: Item {
        Row {
            id: row
            anchors.centerIn: parent
            spacing: 8
            FText {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.count !== ""
                text: root.count
                technical: true
                color: root.selected ? root.inkColor : Design.faint
            }
            FText {
                anchors.verticalCenter: parent.verticalCenter
                text: root.label
                headline: root.large
                technical: !root.large
                font.pixelSize: root.large ? Design.readout : Design.caption
                font.weight: root.large ? Font.Black : Font.Normal
                font.letterSpacing: root.large ? -0.4 : 1.2
                color: root.inkColor
            }
        }
    }
}
