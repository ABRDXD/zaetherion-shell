pragma ComponentBehavior: Bound
import QtQuick

Item {
    id: root
    implicitWidth: 1280
    implicitHeight: 720
    required property bool fluid
    required property string timeText
    required property string dateText
    required property int maskLength
    required property int attempts
    required property bool reducedMotion
    required property real rejectionMs
    required property bool mediaAvailable
    required property string trackTitle
    required property string artist
    required property bool playing
    required property real batteryFraction
    required property real holdProgress
    signal mediaRequested(string action)
    signal powerHoldStarted
    signal powerHoldEnded

    LockLook {
        id: style
        fluid: root.fluid
    }
    // At its designed size, never enlarged (owner, 24 Nov: "too big"); smaller only on a smaller screen.
    readonly property real unit: Math.min(1, root.width / 1280, root.height / 720)
    // The screen in design units: the header across its top corners, the band along its bottom.
    Item {
        width: root.width / root.unit
        height: root.height / root.unit
        transformOrigin: Item.TopLeft
        scale: root.unit
        LockTitleCard {
            anchors.fill: parent
            look: style
            card: false
            timeText: root.timeText
            dateText: root.dateText
        }
        LockBand {
            anchors.fill: parent
            look: style
            mediaAvailable: root.mediaAvailable
            trackTitle: root.trackTitle
            artist: root.artist
            playing: root.playing
            batteryFraction: root.batteryFraction
            holdProgress: root.holdProgress
            onMediaRequested: action => root.mediaRequested(action)
            onPowerHoldStarted: root.powerHoldStarted()
            onPowerHoldEnded: root.powerHoldEnded()
        }
    }
    // The card and the password plane, centred at the designed size.
    Item {
        width: 1280
        height: 720
        anchors.centerIn: parent
        scale: root.unit
        LockTitleCard {
            anchors.fill: parent
            look: style
            chrome: false
            timeText: root.timeText
            dateText: root.dateText
        }
        PasswordPlane {
            anchors.fill: parent
            look: style
            maskLength: root.maskLength
            attempts: root.attempts
            reducedMotion: root.reducedMotion
            rejectionMs: root.rejectionMs
        }
    }
}
