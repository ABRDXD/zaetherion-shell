import QtQuick
import Quickshell
import qs.view.contract
import qs.view.ui

// The island's row, at rest and hovered, balanced around the centred clock (Z124). Each side of the clock is one
// run from the clock to a shoulder:
//   - media fills its run toward the clock, so the title takes whatever the run has left;
//   - the other run is justified, status first, spaced evenly up to the actions;
//   - actions (power, inbox) ride the shoulders, at rest and hovered.
// Status glyphs are quiet (smaller, muted); actions and content are ink.
// Arrangements under review:
//   mirror (Z130 as agreed): power | hover status, media · clock · status, weather, tray | inbox
//   sides:                   weather, tray | media · clock · status, hover status | inbox, power
//   framed (recommended):    power | weather, tray, media · clock · status, hover status | inbox
Item {
    id: root
    required property HostAdapter host
    required property bool wings
    property bool live: true
    property string arrangement: "framed"
    // How far the island reaches past this centre on each side while hovered.
    property real reach: 0
    // The hover fade (0–1) for items that appear only with the wings.
    property real reveal: wings ? 1 : 0
    signal openPanel(string room)
    signal openPower()
    signal openTray(string itemId)

    readonly property bool sides: arrangement === "sides"
    // Power at the right shoulder (Sides) or the left (Mirror, Framed, as in the approved study).
    readonly property bool powerRight: sides
    // Z130 as agreed: the hovered status glyphs grow on the left. Otherwise they join the status run on the right
    // and weather and tray go left, beside the media.
    readonly property bool statusLeft: arrangement === "mirror"
    readonly property bool hovered: wings || reveal > 0
    readonly property var player: host.media.available ? host.media.active : null
    readonly property bool visualising: live && !!player?.playing
    readonly property string networkGlyph: host.network.kind === "ethernet" && host.network.connected
        ? "lan" : host.network.connected ? "wifi" : "wifi_off"
    readonly property int edge: 3 * Design.baseline     // inside each shoulder
    readonly property int gap: 3 * Design.baseline      // between a run and the clock
    readonly property int tight: 2 * Design.baseline    // spacing inside a group
    readonly property real leftShoulder: edge - reach
    readonly property real rightShoulder: width + reach - edge
    readonly property real clockLeft: clock.x
    readonly property real clockRight: clock.x + clock.width
    readonly property real pillMinimum: 200

    // Status glyphs shown only while hovered (Z130's list, trimmed). Network stays in the run at rest, so in Sides the
    // hover list leaves it out; in Mirror the resting network glyph steps aside for the hovered one.
    readonly property var audio: host.audio
    readonly property var hoverStatus: [
        { glyph: networkGlyph, label: "Network", shown: host.network.available && statusLeft },
        { glyph: host.bluetooth.enabled ? "bluetooth" : "bluetooth_disabled", label: "Bluetooth", shown: host.bluetooth.available },
        { glyph: audio.output?.muted ? "volume_off" : "volume_up", label: "Volume", shown: !!audio.output },
        { glyph: audio.input?.muted ? "mic_off" : "mic", label: "Microphone", shown: !!audio.input },
        // Warnings only while they apply. Num lock and the power profile live in the Devices room (owner, 12 November).
        { glyph: "keyboard_capslock", label: "Caps Lock", shown: host.keybinds.capsLock === true },
        { glyph: "flight", label: "Airplane mode", shown: host.network.airplaneMode === true }
    ].filter(entry => entry.shown)

    // How far past the centre the fuller side needs to reach while hovered (IslandSurface.wingSpan).
    function runWidth(items: var, spacing: real): real {
        const shown = items.filter(item => item.visible && item.width > 0);
        return shown.reduce((sum, item) => sum + item.width, 0) + Math.max(0, shown.length - 1) * spacing;
    }
    readonly property real leftNeed: (leftPower.active ? leftPower.width + tight : 0)
        + (leftInfo.width > 0 ? leftInfo.width + tight : 0) + (player ? pillMinimum : 0)
    readonly property real rightNeed: runWidth(right.parts, tight) + gap + actions.width
    readonly property real wingNeed: Math.max(leftNeed, rightNeed) + edge + gap + clock.width / 2 - width / 2

    HostLease {
        domain: root.host.media
        feature: "spectrum"
        active: root.visualising
    }
    HostLease { domain: root.host.audio; feature: "mixer"; active: root.wings && root.live }

    component HoverStatus: Repeater {
        model: root.hovered ? root.hoverStatus : []
        IslandGlyph {
            required property var modelData
            quiet: true
            opacity: root.reveal
            glyph: modelData.glyph
            description: modelData.label
            onClicked: root.openPanel("devices")
        }
    }
    component Weather: Row {
        visible: root.hovered && root.host.weather.available && !!root.host.weather.current
        opacity: root.reveal
        height: Design.minHit
        spacing: Design.baseline
        MaterialSymbol {
            anchors.verticalCenter: parent.verticalCenter
            text: root.host.weather.current?.icon ?? ""
            iconSize: 4 * Design.baseline
            color: Design.muted
        }
        FText {
            anchors.verticalCenter: parent.verticalCenter
            text: root.host.weather.current ? Math.round(root.host.weather.current.tempC) + "°C" : ""
            technical: true
            color: Design.muted
        }
    }
    component Tray: Repeater {
        model: root.hovered && root.host.tray.available ? root.host.tray.items : []
        IslandGlyph {
            required property var modelData
            opacity: root.reveal
            glyph: "apps"
            imageSource: modelData.icon ?? ""
            description: modelData.title
            onClicked: modelData.hasMenu ? root.openTray(modelData.id) : root.host.tray.activate(modelData.id)
        }
    }
    component Power: IslandGlyph {
        glyph: "power_settings_new"
        description: "Session card"
        onClicked: root.openPower()
    }

    // Left run. Power rides the left shoulder (unless it rides the right). The information beside it (the hovered
    // status glyphs under Z130, otherwise weather and tray) follows power when there is media, and the media fills
    // the rest of the run up to the clock. With no media there is no title to match, so the information hugs the
    // clock instead, mirroring the status on the right.
    Loader {
        id: leftPower
        active: !root.powerRight
        x: root.leftShoulder
        anchors.verticalCenter: parent.verticalCenter
        sourceComponent: Power {}
    }
    readonly property real afterPower: leftPower.active ? leftPower.x + leftPower.width + tight : leftShoulder
    Row {
        id: leftInfo
        x: root.player ? root.afterPower : root.clockLeft - root.gap - width
        anchors.verticalCenter: parent.verticalCenter
        spacing: root.tight
        Loader {
            active: !root.statusLeft && root.hovered && root.host.weather.available && !!root.host.weather.current
            visible: active
            sourceComponent: Weather {}
        }
        Loader { active: !root.statusLeft && root.hovered; visible: active; sourceComponent: Row { spacing: root.tight; Tray {} } }
        Loader { active: root.statusLeft && root.hovered; visible: active; sourceComponent: Row { spacing: Design.baseline; HoverStatus {} } }
    }

    Item {
        id: pill
        visible: !!root.player
        x: leftInfo.width > 0 ? leftInfo.x + leftInfo.width + root.tight : root.afterPower
        width: Math.max(104, root.clockLeft - root.gap - x)
        height: Design.minHit
        anchors.verticalCenter: parent.verticalCenter

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

    // Right run: status from one gap past the clock, then (hovered) Mirror's weather and tray or the other
    // arrangements' status glyphs. With media the run is justified up to the actions at the shoulder, to match
    // the title's run; with none it stays a group against the clock. Spacing never drops below the group spacing.
    Row {
        id: right
        readonly property real end: actions.x - root.gap
        readonly property var parts: children
        readonly property real used: root.runWidth(parts, 0)
        readonly property int count: parts.filter(item => item.visible && item.width > 0).length
        x: root.clockRight + root.gap
        anchors.verticalCenter: parent.verticalCenter
        spacing: root.player && count > 1 ? Math.max(root.tight, (end - x - used) / (count - 1)) : root.tight

        IslandGlyph {
            // Mirror: the hovered status run on the left shows Wi-Fi, so this one steps aside.
            visible: root.host.network.available && (!root.statusLeft || !root.wings)
            quiet: true
            glyph: root.networkGlyph
            description: "Network"
            onClicked: root.openPanel("devices")
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
        Item {
            visible: battery.visible
            width: battery.width
            height: Design.minHit
            BatteryMark {
                id: battery
                anchors.verticalCenter: parent.verticalCenter
                battery: root.host.power.battery
                showPercentage: root.wings
                signalOnly: true
                // A status reading: quiet like the glyphs beside it, unless it is calling for attention.
                opacity: tone === Design.accent ? 1 : 0.72
            }
        }
        HoverStatus { model: !root.statusLeft && root.hovered ? root.hoverStatus : [] }
        Weather { visible: root.statusLeft && root.hovered && root.host.weather.available && !!root.host.weather.current }
        Tray { model: root.statusLeft && root.hovered && root.host.tray.available ? root.host.tray.items : [] }
    }

    // Actions at the right shoulder: the inbox, and in Sides the power button after it.
    Row {
        id: actions
        x: root.rightShoulder - width
        anchors.verticalCenter: parent.verticalCenter
        spacing: root.tight
        IslandGlyph {
            visible: root.host.notifications.available
            glyph: "notifications"
            description: "Inbox"
            signalDot: root.host.notifications.unread > 0
            onClicked: root.openPanel("notifications")
        }
        Loader { active: root.powerRight; visible: active; sourceComponent: Power {} }
    }
}
