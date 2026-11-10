import qs.view.cues
import qs.view.ui
import QtQuick
import "Occultation.js" as Occ

// Clock occultation (docs/OVERDRIVE_IDEAS.md #51, docs/OVERDRIVE.md §50): the header's clock is a portal, never a
// label that gives way. In Silent it is the plain line it always was. In Overdrive, events cross it by how much they
// matter (view/overdrive/Occultation.js): a countdown's end splits the colon, its dots part like an eclipse's limbs
// and the Timers room's number stands between the hours and the minutes while the header makes room; a device
// coming or going crosses in front as a plate that prints the digits it covers in negative; a new track passes
// behind the digits as a band. The digits stay readable throughout. Release clears the event and destroys the layer.
Item {
    id: root
    property string hours: ""
    property string minutes: ""
    property string suffix: "   LOCAL"
    property var event: null
    property real now: 0
    readonly property real u: Motion.driving ? Occ.progress(event, now) : -1
    readonly property bool crossing: u >= 0
    readonly property string plane: crossing ? Occ.plane(event.kind) : ""
    readonly property real open: plane === "split" ? Occ.opening(u) * Motion.drive : 0
    // The split's width: the room number and a clear margin either side of it.
    readonly property real gap: open * (splitNumber.implicitWidth + 16)
    readonly property color tone: !crossing ? Design.muted : event.kind === "timer" ? Design.warm : event.kind === "media" ? Design.mediaAccent : Design.accent
    implicitWidth: plain.implicitWidth + gap
    implicitHeight: plain.implicitHeight

    // index: the room's place in the index ribbon (Home 0). Ignored outside Overdrive, so Silent never moves.
    function occult(kind, index) {
        if (!Motion.driving)
            return;
        root.now = Date.now();
        root.event = Occ.admit(root.event, kind, index, root.now);
    }

    Connections {
        target: Motion
        function onDrivingChanged() { if (!Motion.driving) root.event = null; }
    }
    FrameAnimation {
        running: root.event !== null && Motion.driving
        onTriggered: {
            root.now = Date.now();
            if (!Occ.active(root.event, root.now))
                root.event = null;
        }
    }

    // The clock as it has always been. Hidden only while the split sets its pieces apart.
    FText {
        id: plain
        text: root.hours + ":" + root.minutes + root.suffix
        technical: true
        font.pixelSize: Design.caption
        // A band behind lifts the digits to full ink, so they read in front of it.
        color: root.plane === "behind" ? Qt.tint(Design.muted, Qt.alpha(Design.ink, Motion.drive)) : Design.muted
        opacity: root.plane === "split" ? 0 : 1
    }
    // Measures only: the room number's width sets the split's.
    FText {
        id: splitNumber
        visible: false
        text: root.crossing ? Occ.roomNumber(root.event.room) : "00"
        technical: true
        font.pixelSize: Design.body
        font.weight: Font.Black
    }

    Loader {
        anchors.fill: parent
        active: root.crossing
        z: root.plane === "behind" ? -1 : 1
        sourceComponent: root.plane === "split" ? split : root.plane === "front" ? front : behind
    }

    // A countdown's end: the hours keep their place, the colon's dots part (the upper with the hours, the lower
    // with the minutes), and the room's number is set between them on two hairlines, in register with the digits.
    Component {
        id: split
        Item {
            FText {
                id: h
                text: root.hours
                technical: true
                font.pixelSize: Design.caption
                color: Qt.tint(Design.muted, Qt.alpha(root.tone, 0.5 * root.open))
            }
            FText {
                id: colon
                visible: false
                text: ":"
                technical: true
                font.pixelSize: Design.caption
            }
            Repeater {
                model: 2
                Item {
                    required property int index
                    x: h.implicitWidth + index * root.gap
                    y: (index === 0 ? -3 : 3) * root.open
                    width: colon.implicitWidth
                    height: colon.implicitHeight / 2
                    clip: true
                    FText {
                        y: -index * parent.height
                        text: ":"
                        technical: true
                        font.pixelSize: Design.caption
                        color: Qt.tint(Design.muted, Qt.alpha(root.tone, root.open))
                    }
                }
            }
            Item {
                x: h.implicitWidth + colon.implicitWidth / 2
                width: root.gap
                height: parent.height
                opacity: Math.max(0, root.open * 1.4 - 0.4)
                Rectangle { y: -2; width: parent.width; height: 1; color: root.tone }
                Rectangle { y: parent.height + 1; width: parent.width; height: 1; color: root.tone }
                FText {
                    anchors.centerIn: parent
                    // In register only once the split is fully open: it slides the last pixels into place.
                    anchors.horizontalCenterOffset: (1 - root.open) * 4
                    text: Occ.roomNumber(root.event?.room ?? 0)
                    technical: true
                    font.pixelSize: Design.body
                    font.weight: Font.Black
                    color: root.tone
                }
            }
            FText {
                x: h.implicitWidth + colon.implicitWidth + root.gap
                text: root.minutes + root.suffix
                technical: true
                font.pixelSize: Design.caption
                color: Design.muted
            }
        }
    }

    // A device: a plate crosses in front at a constant rate, left to right, and prints the digits it covers in
    // negative. Its room's number rides above its leading edge.
    Component {
        id: front
        Item {
            id: frontLayer
            readonly property real body: Math.max(18, root.implicitWidth * 0.28)
            readonly property real px: Occ.transit(root.u, root.width, body, false)
            Item {
                x: frontLayer.px
                y: -4
                width: frontLayer.body
                height: root.height + 8
                clip: true
                opacity: Motion.drive
                Rectangle { anchors.fill: parent; color: root.tone }
                FText {
                    x: -frontLayer.px
                    y: 4
                    text: plain.text
                    technical: true
                    font.pixelSize: Design.caption
                    color: Design.background
                }
            }
            FText {
                x: frontLayer.px + frontLayer.body - implicitWidth
                y: -4 - implicitHeight
                text: Occ.roomNumber(root.event?.room ?? 0)
                technical: true
                font.pixelSize: Design.caption
                color: root.tone
                opacity: Motion.drive
            }
        }
    }

    // A new track: a band passes behind the digits, right to left, the music's room number at its head. The digits
    // stay on top in their own ink.
    Component {
        id: behind
        Item {
            id: behindLayer
            readonly property real body: Math.max(30, root.implicitWidth * 0.55)
            readonly property real px: Occ.transit(root.u, root.width, body, true)
            Rectangle {
                x: behindLayer.px
                y: root.height * 0.22
                width: behindLayer.body
                height: root.height * 0.56
                color: Qt.alpha(root.tone, 0.16 * Motion.drive)
                Rectangle { width: 1; height: parent.height; color: Qt.alpha(root.tone, 0.8 * Motion.drive) }
            }
            FText {
                x: behindLayer.px
                y: root.height + 1
                text: Occ.roomNumber(root.event?.room ?? 0)
                technical: true
                font.pixelSize: Design.caption
                color: root.tone
                opacity: Motion.drive
            }
        }
    }
}
