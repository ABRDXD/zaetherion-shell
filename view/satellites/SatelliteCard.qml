import QtQuick
import qs.view.cues
import qs.view.ui

// One satellite's face: a label, a value and an optional second line. `inverted` swaps paper and
// ink (DONE). `flash` asks FlashGate for one pulse when the card appears; denied or reduced, the
// card is simply static.
Item {
    id: root
    property string label: ""
    property string value: ""
    property string detail: ""
    property bool inverted: false
    property bool flash: false
    // Track-change text fades in with the swap role.
    property bool fade: false
    signal activated()
    implicitWidth: Math.max(140, row.implicitWidth + 24, detailText.visible ? detailText.implicitWidth + 24 : 0)
    implicitHeight: column.implicitHeight + 16
    opacity: fade ? entrance.value : 1

    FFrame {
        anchors.fill: parent
        fillColor: root.inverted ? Design.ink : Qt.alpha(Design.background, Design.panelOpacity)
        lineColor: root.inverted ? Design.ink : Design.line
    }
    // The flash: a brief full-ink wash over the inverted card.
    Rectangle {
        anchors.fill: parent
        color: Design.background
        opacity: pulse.value * 0.8
        visible: pulse.value > 0
    }
    Column {
        id: column
        x: 12
        y: 8
        width: parent.width - 24
        spacing: 2
        Row {
            id: row
            spacing: 10
            FText {
                visible: root.label !== ""
                text: root.label
                technical: true
                color: root.inverted ? Design.background : Design.muted
                anchors.baseline: valueText.baseline
            }
            FText {
                id: valueText
                text: root.value
                font.pixelSize: Design.readout
                font.capitalization: Font.MixedCase
                color: root.inverted ? Design.background : Design.ink
            }
        }
        FText {
            id: detailText
            visible: root.detail !== ""
            width: Math.min(implicitWidth, 320)
            text: root.detail
            technical: true
            aside: true
            font.capitalization: Font.MixedCase
            color: root.inverted ? Design.background : Design.muted
        }
    }
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            Feedback.play("ui.click");
            root.activated();
        }
    }
    Pulse {
        id: pulse
        scope: root
        name: "satellite.flash"
        flash: true
        attack: Motion.feedback
        release: Motion.swap
    }
    Cue {
        id: entrance
        scope: root
        on: true
        name: "satellite.fade"
        enter: Motion.swap
        easing: Motion.roles.swap.easing
    }
    // The arrival plays once, when the card first becomes live (its surface may map a frame later).
    property bool arrived: false
    function arrive() {
        if (arrived || !pulse.live)
            return;
        arrived = true;
        if (flash)
            pulse.trigger();
        if (fade)
            entrance.replay();
    }
    Connections {
        target: pulse
        function onLiveChanged() { root.arrive(); }
    }
    Component.onCompleted: arrive()
}
