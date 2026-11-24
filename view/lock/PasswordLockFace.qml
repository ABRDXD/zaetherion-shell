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
    Item {
        width: 1280
        height: 720
        anchors.centerIn: parent
        scale: Math.min(root.width / width, root.height / height)
        LockTitleCard {
            anchors.fill: parent
            look: style
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
}
