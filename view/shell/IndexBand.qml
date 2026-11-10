import qs.view.cues
import qs.view.ui
import QtQuick
import QtQuick.Controls

// One tab of the index ribbon (MONTAGE.md §4). At rest a small numbered parallelogram; selected, it grows
// into an inverted ink tab carrying the number and the room's name, with a thin rule above and below
// it (the sheet's selection mark). The ribbon stands on whichever edge the current room gives it.
AbstractButton {
    id: band
    required property var modelData
    required property int index
    property bool selected: false
    property bool compact: false
    readonly property real restHeight: 26
    readonly property real titleHeight: compact ? 40 : 56
    // 0 at rest, 1 selected. Input never waits for it (CUES rule 1).
    readonly property real reveal: cue.value
    readonly property string number: String(index).padStart(2, "0")

    height: restHeight + (titleHeight - restHeight) * reveal
    hoverEnabled: true
    padding: 0
    Accessible.name: modelData.name
    Accessible.description: modelData.about ?? ""
    ToolTip.visible: hovered && !selected
    ToolTip.text: modelData.name
    ToolTip.delay: 500

    // Hover, eased (a Tween: only while the pointer moves it): a paper sweep from the left along 78°, and the
    // number nudged towards the room.
    property real hoverLit: hovered && !selected ? 1 : 0
    Tween on hoverLit {
        scope: band
        NumberAnimation { duration: Motion.settle; easing.type: Easing.OutCubic }
    }
    Cue {
        id: cue
        name: "index.band"
        on: band.selected
        scope: band
        enter: Motion.navigate
        easing: Motion.roles.navigate.easing
    }

    background: Item {
        Plane {
            id: face
            anchors.fill: parent
            slant: 3
            role: band.selected ? "ink" : "clear"
            backing: band.selected
        }
        Plane {
            visible: band.hoverLit > 0 && !band.selected
            width: face.run + band.hoverLit * (parent.width - face.run)
            height: parent.height
            role: "paper"
            slant: 3
        }
        // The selection rules, 3 px clear of the tab.
        Rectangle {
            y: -4
            width: parent.width
            height: 1
            color: Design.ink
            opacity: band.reveal
            visible: opacity > 0
        }
        Rectangle {
            y: parent.height + 3
            width: parent.width
            height: 1
            color: Design.ink
            opacity: band.reveal
            visible: opacity > 0
        }
    }
    contentItem: Item {
        FText {
            anchors.centerIn: parent
            opacity: 1 - band.reveal
            visible: opacity > 0
            text: band.number
            technical: true
            sheared: false
            font.pixelSize: Design.control
            color: band.hoverLit > 0.5 ? Design.ink : Design.faint
            transform: Translate { x: 5 * band.hoverLit }
        }
        Column {
            anchors.centerIn: parent
            width: parent.width - 10
            opacity: band.reveal
            visible: opacity > 0
            spacing: 0
            FText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: band.number
                headline: true
                sheared: false
                font.pixelSize: band.compact ? Design.readout : Design.figure
                font.weight: Font.Black
                color: Design.onInk ?? Design.background
            }
            FText {
                visible: !band.compact
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: band.modelData.name
                technical: true
                sheared: false
                fontSizeMode: Text.HorizontalFit
                minimumPixelSize: 7 // scale: the floor of the fitted name
                font.pixelSize: Design.caption
                font.letterSpacing: 0
                color: Design.onInk ?? Design.background
            }
        }
    }
}
