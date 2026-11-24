pragma ComponentBehavior: Bound
import QtQuick

Item {
    id: root
    required property LockLook look
    required property string trackTitle
    required property string artist
    required property bool mediaAvailable
    required property bool playing
    // Negative when unavailable. Otherwise in [0, 1].
    required property real batteryFraction
    required property real holdProgress
    signal mediaRequested(string action)
    signal powerHoldStarted
    signal powerHoldEnded

    Rectangle {
        x: root.look.fluid ? 88 : 0
        y: root.look.fluid ? 611 : 614
        width: root.look.fluid ? 1104 : 1280
        height: root.look.fluid ? 77 : 106
        color: root.look.fluid ? "#282738" : "#1c2931"
        radius: root.look.fluid ? height / 2 : 0
        border.width: root.look.fluid ? 1 : 0
        border.color: "#625b74"
        Rectangle {
            visible: !root.look.fluid
            width: parent.width
            height: 1
            color: "#626b6d"
        }
        Row {
            visible: root.mediaAvailable
            x: root.look.fluid ? 33 : 52
            anchors.verticalCenter: parent.verticalCenter
            spacing: 16
            Rectangle {
                width: 48
                height: 48
                radius: root.look.fluid ? 24 : 0
                color: root.look.fluid ? "#4d425d" : "#394b51"
                clip: true
                Row {
                    anchors.centerIn: parent
                    spacing: 3
                    Repeater {
                        model: [9, 18, 26, 13, 20, 8]
                        Rectangle {
                            required property int modelData
                            y: (26 - height) / 2
                            width: 2
                            height: modelData
                            color: root.look.accent
                        }
                    }
                }
            }
            Column {
                width: 290
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                LockText {
                    look: root.look
                    width: parent.width
                    elide: Text.ElideRight
                    text: root.trackTitle
                    font.pixelSize: root.look.track
                    font.weight: Font.DemiBold
                }
                LockText {
                    look: root.look
                    technical: true
                    width: parent.width
                    elide: Text.ElideRight
                    text: root.artist
                    font.letterSpacing: 0.25
                    color: "#c3c3cb"
                }
            }
        }
        Row {
            visible: root.mediaAvailable
            anchors.centerIn: parent
            spacing: 10
            Repeater {
                model: ["previous", "playPause", "next"]
                Rectangle {
                    id: control
                    required property string modelData
                    readonly property bool primary: modelData === "playPause"
                    readonly property string action: primary ? (root.playing ? "pause" : "play") : modelData
                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.mediaRequested(control.action)
                    }
                    width: 47
                    height: 40
                    radius: root.look.fluid ? 20 : 0
                    color: primary ? root.look.accent : "transparent"
                    LockGlyph {
                        anchors.centerIn: parent
                        width: 21
                        height: 21
                        mark: control.action
                        ink: control.primary ? "#262a32" : root.look.ink
                    }
                }
            }
        }
        Row {
            anchors.right: parent.right
            anchors.rightMargin: root.look.fluid ? 28 : 52
            anchors.verticalCenter: parent.verticalCenter
            spacing: 12
            LockGlyph {
                visible: root.batteryFraction >= 0
                anchors.verticalCenter: parent.verticalCenter
                width: 24
                height: 24
                mark: "battery"
                batteryFraction: root.batteryFraction
            }
            LockText {
                look: root.look
                technical: true
                visible: root.batteryFraction >= 0
                anchors.verticalCenter: parent.verticalCenter
                text: Math.round(root.batteryFraction * 100) + "%"
            }
            Item {
                width: 13
                height: 1
            }
            Rectangle {
                width: 171
                height: 41
                radius: root.look.fluid ? 21 : 0
                color: root.holdProgress > 0 ? "#45404a" : "transparent"
                border.color: root.look.fluid ? "#7c738e" : "#627277"
                Rectangle {
                    x: 15
                    y: parent.height - 5
                    width: (parent.width - 30) * root.holdProgress
                    height: 2
                    color: root.look.accent
                    visible: root.holdProgress > 0
                }
                MouseArea {
                    anchors.fill: parent
                    onPressed: root.powerHoldStarted()
                    onReleased: root.powerHoldEnded()
                    onCanceled: root.powerHoldEnded()
                }
                Row {
                    anchors.centerIn: parent
                    spacing: 9
                    LockGlyph {
                        width: 17
                        height: 17
                        mark: "power"
                        ink: root.look.accent
                    }
                    LockText {
                        look: root.look
                        technical: true
                        text: "Hold for power"
                        font.letterSpacing: 0.2
                    }
                }
            }
        }
    }
}
