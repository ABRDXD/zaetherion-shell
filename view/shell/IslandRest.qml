import QtQuick
import Quickshell
import qs.view.contract
import qs.view.ui
import "NetWords.js" as NetWords

// The island's row, at rest and hovered, balanced around the centred clock (Z124). Each side of the clock is one
// run from the clock to a shoulder:
//   - media fills its run toward the clock, so the title takes whatever the run has left;
//   - the other run is a packed group, status first, starting one gap past the clock;
//   - actions (power, inbox) ride the shoulders, at rest and hovered.
// Status glyphs are quiet (smaller, muted); actions and content are ink.
// Framed (Z149): power | weather, tray, media · clock · status, hover status | inbox
Item {
    id: root
    required property HostAdapter host
    required property bool wings
    property bool live: true
    // How far the island reaches past this centre on each side while hovered.
    property real reach: 0
    // The hover fade (0–1) for items that appear only with the wings.
    property real reveal: wings ? 1 : 0
    signal openPanel(string room)
    // FART's settings at a section ("wifi", "bluetooth"): a glyph with a hover word opens where that is happening.
    signal openSettings(string section)
    signal openPower()
    // What shows at rest (Z176, FART's Island tab): each item "always", "matters" (only while it needs you) or
    // "hover"; the inbox may also be "unread" (its bell while anything is unread) or "dot" (no bell at rest: a dot on
    // the last status glyph while anything is unread). Hovered, everything shows as before. The default is the rest
    // as it was. The owner's rest (B, 14 November): power on hover, Wi-Fi and battery always, the inbox as a dot.
    property var restItems: ({})
    readonly property bool batteryLow: !!host.power.battery?.available && !host.power.battery?.pluggedIn
        && (host.power.battery?.level ?? 1) <= 0.2
    readonly property bool networkDown: host.network.available && !host.network.connected
    readonly property bool unreadCritical: host.notifications.items.some(item => item.urgency === "critical" && !item.read)
    function atRest(item: string, matters: bool): bool {
        const mode = restItems[item] ?? "always";
        return hovered || mode === "always" || (mode === "matters" && matters)
            || (mode === "unread" && host.notifications.unread > 0);
    }
    // The bell is not at rest: the status run moves out to the shoulder in its place.
    readonly property bool inboxAtRest: host.notifications.available && atRest("inbox", unreadCritical)
    readonly property bool statusAtEdge: !hovered && !inboxAtRest
    readonly property bool unreadDot: !hovered && (restItems.inbox ?? "always") === "dot" && host.notifications.unread > 0
    readonly property bool batteryShown: !!host.power.battery?.available && atRest("battery", batteryLow)
    signal openTray(string itemId)

    // Fluid at rest (Z145): the clock alone, or the track and its waveform either side of it while playing.
    // Hovered, Fluid shows the same row as Angular inside its rounded ends.
    readonly property bool compact: Design.fluid && !wings
    // Fluid at rest while a player plays: the media instead of the clock, as DMS does. Right-click on the island
    // flips this (IslandSurface.preferClock).
    property bool preferClock: false
    readonly property bool mediaView: compact && visualising && !preferClock
    // The width Fluid needs at rest: the clock alone, or the media row.
    readonly property real compactWidth: mediaView ? Math.ceil(mediaRow.implicitWidth) + 2 * edge : 100
    readonly property bool hovered: wings || reveal > 0
    readonly property var player: host.media.available ? host.media.active : null
    readonly property bool visualising: live && !!player?.playing
    // One word while hovered when something is happening (docs/NET_BT.md §5): "joining", "wrong password", "pairing".
    readonly property string wifiWord: NetWords.wifiWord(host.network.attempt, host.network.prompt)
    readonly property string bluetoothWord: NetWords.bluetoothWord(host.bluetooth.attempts, host.bluetooth.pairing)
    readonly property string networkGlyph: host.network.kind === "ethernet" && host.network.connected
        ? "lan" : host.network.connected ? "wifi" : "wifi_off"
    // Inside each end: Angular's shoulders take little, Fluid's flare and corners take more, so Fluid keeps
    // 16 px of clear padding past its flare.
    readonly property int edge: Design.fluid ? Design.roundEar + 4 * Design.baseline : 3 * Design.baseline
    readonly property int gap: 3 * Design.baseline      // between a run and the clock
    // One rhythm between every glyph on both sides (owner, 12 November): nothing is spread to fill a run.
    readonly property int tight: 3 * Design.baseline
    readonly property real leftShoulder: edge - reach
    readonly property real rightShoulder: width + reach - edge
    readonly property real clockLeft: clock.x
    readonly property real clockRight: clock.x + clock.width
    // The title's share of the hovered width; any width the other side leaves goes to the title.
    readonly property real pillMinimum: 140

    // Status glyphs shown only while hovered (Z130's list, trimmed). Network stays in the resting run, so the hover
    // list leaves it out.
    readonly property var audio: host.audio
    readonly property var hoverStatus: [
        { glyph: host.bluetooth.enabled ? "bluetooth" : "bluetooth_disabled", label: "Bluetooth", shown: host.bluetooth.available,
          word: bluetoothWord, section: "bluetooth" },
        { glyph: audio.output?.muted ? "volume_off" : "volume_up", label: "Volume", shown: !!audio.output },
        { glyph: audio.input?.muted ? "mic_off" : "mic", label: "Microphone", shown: !!audio.input },
        // Warnings only while they apply. Num lock and the power profile live in the Devices room (owner, 12 November).
        { glyph: "keyboard_capslock", label: "Caps Lock", shown: host.keybinds.capsLock === true },
        { glyph: "flight", label: "Airplane mode", shown: host.network.airplaneMode === true }
    ].filter(entry => entry.shown)

    // How much the fuller side needs while hovered (IslandSurface.wingSpan).
    function runWidth(items: var, spacing: real): real {
        const shown = items.filter(item => item.visible && item.width > 0);
        return shown.reduce((sum, item) => sum + item.width, 0) + Math.max(0, shown.length - 1) * spacing;
    }
    readonly property real leftNeed: (leftPower.active ? leftPower.width + tight : 0)
        + (leftInfo.width > 0 ? leftInfo.width + tight : 0) + (player ? pillMinimum : 0)
    readonly property real rightNeed: runWidth(right.parts, tight) + gap + actions.width
    // From the clock's centre to the shoulder on the fuller side. IslandSurface subtracts its target centre width,
    // never this item's animating width, so the hovered width does not loop through itself.
    readonly property real sideNeed: Math.max(leftNeed, rightNeed) + edge + gap + clock.width / 2

    HostLease {
        domain: root.host.media
        feature: "spectrum"
        active: root.visualising
    }
    HostLease { domain: root.host.audio; feature: "mixer"; active: root.wings && root.live }

    component HoverStatus: Repeater {
        model: root.hovered ? root.hoverStatus : []
        Row {
            id: status
            required property var modelData
            readonly property string word: modelData.word ?? ""
            function open(): void {
                if (word) root.openSettings(modelData.section);
                else root.openPanel("devices");
            }
            spacing: Design.baseline
            opacity: root.reveal
            IslandGlyph {
                quiet: true
                glyph: status.modelData.glyph
                description: status.word ? status.modelData.label + ": " + status.word : status.modelData.label
                onClicked: status.open()
            }
            HoverWord {
                word: status.word
                onClicked: status.open()
            }
        }
    }
    // The hover word itself: quiet unless it needs the person ("wrong password"); a click does what its glyph does.
    component HoverWord: FText {
        id: hoverWord
        property string word: ""
        signal clicked()
        visible: root.hovered && word !== ""
        anchors.verticalCenter: parent.verticalCenter
        technical: true
        text: word
        color: word === "wrong password" ? Design.accent : Design.muted
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: hoverWord.clicked()
        }
    }
    component Weather: Row {
        visible: root.hovered && root.host.weather.available && !!root.host.weather.current
        opacity: root.reveal
        height: Design.minHit
        spacing: Design.baseline
        MaterialSymbol {
            fill: Design.iconFill
            weight: Design.iconWeight
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

    // Left run. Power rides the left shoulder. Weather and tray follow power when there is media, and the media fills
    // the rest of the run up to the clock. With no media there is no title to match, so the information hugs the
    // clock instead, mirroring the status on the right.
    Loader {
        id: leftPower
        active: !root.compact && root.atRest("power", false)
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
            active: root.hovered && root.host.weather.available && !!root.host.weather.current
            visible: active
            sourceComponent: Weather {}
        }
        Loader { active: root.hovered; visible: active; sourceComponent: Row { spacing: root.tight; Tray {} } }
    }

    Item {
        id: pill
        visible: !!root.player && !root.compact
        x: leftInfo.width > 0 ? leftInfo.x + leftInfo.width + root.tight : root.afterPower
        width: root.compact ? Math.max(0, root.clockLeft - root.gap - x) : Math.max(104, root.clockLeft - root.gap - x)
        height: Design.minHit
        anchors.verticalCenter: parent.verticalCenter

        // The player's mark, inverted on signal as in the approved study (Z144).
        FPlate {
            id: art
            width: Design.readout
            height: width
            anchors.verticalCenter: parent.verticalCenter
            radius: Design.roundSmall
            slant: 0
            role: "signal"
            MaterialSymbol {
                fill: Design.iconFill
                weight: Design.iconWeight
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
            y: root.visualising && !root.compact ? 0 : (parent.height - height) / 2
            technical: true
            text: root.player?.title ?? ""
        }
        Loader {
            anchors.left: art.right
            anchors.leftMargin: Design.baseline
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: Design.baseline * 2
            active: root.visualising && !root.compact
            sourceComponent: LineWaveform { levels: root.host.media.spectrum }
        }
    }
    // Fluid at rest while playing: the art, the live waveform and the title, centred where the clock was.
    Row {
        id: mediaRow
        visible: root.mediaView
        anchors.centerIn: parent
        spacing: Design.baseline * 2
        FPlate {
            width: Design.readout
            height: width
            anchors.verticalCenter: parent.verticalCenter
            radius: Design.roundSmall
            slant: 0
            role: "signal"
            MaterialSymbol {
                fill: Design.iconFill
                weight: Design.iconWeight
                anchors.fill: parent
                text: "music_note"
                iconSize: Design.control
                color: parent.textColor
                visible: mediaCover.status !== Image.Ready
            }
            Image {
                id: mediaCover
                anchors.fill: parent
                source: root.player?.artUrl ?? ""
                sourceSize.width: Design.readout
                sourceSize.height: Design.readout
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }
        }
        Loader {
            width: Design.readout + Design.baseline
            height: Design.baseline * 3
            anchors.verticalCenter: parent.verticalCenter
            active: root.mediaView
            sourceComponent: LineWaveform { levels: root.host.media.spectrum }
        }
        FText {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, 240)
            font.capitalization: Font.MixedCase
            text: root.player?.title ?? ""
        }
    }

    Loader {
        id: seconds
        active: root.wings && root.live
        sourceComponent: SystemClock { precision: SystemClock.Seconds }
    }
    FText {
        id: clock
        visible: !root.mediaView
        anchors.centerIn: parent
        headline: true
        font.weight: Font.Bold
        font.pixelSize: Design.readout
        sheared: !Design.fluid
        text: seconds.item ? Qt.formatTime(seconds.item.date, "HH:mm:ss") : Clock.hourStr + ":" + Clock.minuteStr
    }

    // Right run: status from one gap past the clock, then (hovered) the hover status glyphs, packed at the shared
    // rhythm. The hovered width is set by the fuller side, so the
    // inbox at the shoulder follows straight on unless the left side is the fuller one.
    Row {
        id: right
        visible: !root.compact
        readonly property real end: actions.x - root.gap
        readonly property var parts: children
        readonly property real used: root.runWidth(parts, 0)
        readonly property int count: parts.filter(item => item.visible && item.width > 0).length
        x: root.statusAtEdge ? root.rightShoulder - width : root.clockRight + root.gap
        anchors.verticalCenter: parent.verticalCenter
        spacing: root.tight

        IslandGlyph {
            visible: root.host.network.available && root.atRest("network", root.networkDown)
            quiet: !root.networkDown
            // The unread dot rides the last status glyph; with no battery that is this one.
            signalDot: root.unreadDot && !root.batteryShown
            glyph: root.networkGlyph
            description: root.wifiWord ? "Network: " + root.wifiWord : "Network"
            onClicked: root.wifiWord ? root.openSettings("wifi") : root.openPanel("devices")
        }
        HoverWord {
            opacity: root.reveal
            word: root.wifiWord
            onClicked: root.wifiWord ? root.openSettings("wifi") : root.openPanel("devices")
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
            // From the data, not from the mark: the mark's visibility includes this item's, which would lock both
            // hidden once anything hid the row.
            visible: root.batteryShown
            width: battery.width
            height: Design.minHit
            BatteryMark {
                id: battery
                anchors.verticalCenter: parent.verticalCenter
                battery: root.host.power.battery
                showPercentage: root.wings
                signalOnly: true
                rounded: Design.fluid
                // A status reading: quiet like the glyphs beside it, unless it is calling for attention.
                opacity: tone === Design.accent ? 1 : 0.72
            }
            // Unread notifications while the bell is not at rest (IslandGlyph's dot, at the mark's corner).
            Rectangle {
                visible: root.unreadDot
                x: battery.x + battery.width - width / 2
                y: battery.y - height / 2
                width: Design.baseline
                height: width
                radius: width / 2
                color: Design.accent
            }
        }
        HoverStatus {}
    }

    // Actions at the right shoulder: the inbox.
    Row {
        id: actions
        visible: !root.compact
        x: root.rightShoulder - width
        anchors.verticalCenter: parent.verticalCenter
        spacing: root.tight
        IslandGlyph {
            visible: root.host.notifications.available && root.atRest("inbox", root.unreadCritical)
            glyph: "notifications"
            description: "Inbox"
            signalDot: root.host.notifications.unread > 0
            onClicked: root.openPanel("notifications")
        }
    }
}
