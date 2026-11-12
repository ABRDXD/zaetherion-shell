import QtQuick
import Quickshell
import qs.view.contract
import qs.view.ui

Item {
    id: root
    required property HostAdapter host
    required property bool wings
    property bool live: true
    signal openPanel(string room)
    signal openPower()

    readonly property var player: host.media.available ? host.media.active : null
    readonly property bool visualising: live && !!player?.playing
    readonly property string networkGlyph: host.network.kind === "ethernet" && host.network.connected
        ? "lan" : host.network.connected ? "wifi" : "wifi_off"

    HostLease {
        domain: root.host.media
        feature: "spectrum"
        active: root.visualising
    }

    // The left half holds power and the media pill; the pill runs up to the clock so the title gets every
    // pixel the centred clock leaves. Network sits with the other status glyphs on the right (Z66: contents
    // rearrange inside the resting width).
    Row {
        id: leftGroup
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        spacing: Design.baseline

        IslandGlyph {
            glyph: "power_settings_new"
            description: "Session card"
            onClicked: root.openPower()
        }
        Item {
            id: pill
            visible: !!root.player
            width: Math.max(104, clock.x - 3 * Design.baseline - leftGroup.x - x)
            height: Design.minHit

            // The player's mark, inverted on signal as in the approved study (Z144).
            Plane {
                id: art
                width: Design.readout
                height: width
                anchors.verticalCenter: parent.verticalCenter
                role: "signal"
                MaterialSymbol {
                    anchors.fill: parent
                    text: "music_note"
                    iconSize: Design.control
                    color: art.textColor
                    visible: cover.status !== Image.Ready
                }
                Image {
                    id: cover
                    anchors.fill: parent
                    source: root.player?.artUrl ?? ""
                    sourceSize.width: Design.readout
                    sourceSize.height: Design.readout
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
            }
            FText {
                anchors.left: art.right
                anchors.leftMargin: Design.baseline
                anchors.right: parent.right
                y: root.visualising ? 0 : (parent.height - height) / 2
                technical: true
                text: root.player?.title ?? ""
            }
            Loader {
                anchors.left: art.right
                anchors.leftMargin: Design.baseline
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: Design.baseline * 2
                active: root.visualising
                sourceComponent: LineWaveform { levels: root.host.media.spectrum }
            }
        }
    }

    Loader {
        id: seconds
        active: root.wings && root.live
        sourceComponent: SystemClock { precision: SystemClock.Seconds }
    }
    FText {
        id: clock
        anchors.centerIn: parent
        headline: true
        font.weight: Font.Bold
        font.pixelSize: Design.readout
        sheared: true
        text: seconds.item ? Qt.formatTime(seconds.item.date, "HH:mm:ss") : Clock.hourStr + ":" + Clock.minuteStr
    }

    Row {
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        spacing: Design.baseline * 2

        IslandGlyph {
            visible: root.host.network.available
            glyph: root.networkGlyph
            description: "Network"
            onClicked: root.openPanel("devices")
        }
        IslandGlyph {
            visible: root.host.notifications.available
            glyph: "notifications"
            description: "Inbox"
            signalDot: root.host.notifications.unread > 0
            onClicked: root.openPanel("notifications")
        }
        IslandGlyph {
            visible: root.host.audio.privacy.length > 0
            glyph: root.host.audio.privacy.some(stream => stream.kind === "camera") ? "videocam" : "mic"
            signalDot: true
            description: root.host.audio.privacy.map(stream => stream.app).join(", ")
            onClicked: root.openPanel("devices")
        }
        FText {
            visible: root.wings && root.host.audio.privacy.length > 0
            anchors.verticalCenter: parent.verticalCenter
            width: 52
            technical: true
            text: root.host.audio.privacy.map(stream => stream.app).join(", ")
        }
        BatteryMark {
            anchors.verticalCenter: parent.verticalCenter
            battery: root.host.power.battery
            showPercentage: root.wings
            signalOnly: true
        }
    }
}
