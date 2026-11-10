import qs.view.contract
import qs.view.shell
import qs.view.strata
import qs.view.ui
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import "Ports.js" as Ports

// Devices (MONTAGE §5): the two links are the hero, each a whole plane one click from on or off.
// Under them, the power mode as tabs and the small switches. Then sound and light, ruled, beside the
// link panel: nearby networks (the scan lease is held only while that list is shown), paired devices,
// and the mixer. Capture and the address at the foot.
ColumnLayout {
    id: root
    required property HostAdapter host
    required property ShellContext shell
    signal openDialog(string kind)
    readonly property var audio: host.audio
    readonly property var network: host.network
    readonly property var bluetooth: host.bluetooth
    readonly property var power: host.power
    readonly property var sinks: audio.outputs
    readonly property var sources: audio.inputs
    readonly property var streams: audio.streams
    readonly property var capture: host.hostActions.recording
    readonly property bool recording: capture.active
    readonly property bool active: root.visible && (root.QsWindow.window?.visible ?? false) && root.shell.panelOpen
    readonly property bool narrow: width < 730
    // The link planes grow with a tall room (the 1360 × 860 panel), up to 140 px.
    readonly property real linkHeight: Math.round(Math.max(104, Math.min(140, height * 0.17)))
    // A wide room (the 1360 px panel) gives the mixer its own column; the link panel then has two pages.
    readonly property bool wide: width >= 1000
    // The link panel's page: "mixer" (the default, no extra cost), "nearby" or "paired".
    property string panel: "mixer"
    readonly property string page: wide && panel === "mixer" ? "paired" : panel
    property double now: Date.now()
    readonly property int recordedSeconds: capture.startedAt > 0 ? Math.max(0, Math.floor(now / 1000 - capture.startedAt)) : 0
    readonly property var profileLabels: ({ "power-saver": "Saver", "balanced": "Balanced", "performance": "Performance" })
    readonly property var nearby: network.networks.slice().sort((a, b) => (b.connected - a.connected) || (b.known - a.known) || (b.strength - a.strength))
    // The weather's reports (core/weather.py), for the battery ledger: asked once each time the room is shown.
    property var weather: null
    onActiveChanged: if (active) shell.core?.request("weather.now", {}, (ok, result) => { if (ok && result && root) root.weather = result; })
    readonly property var paired: bluetooth.devices
    // Phantom ports (Ports.js, atlas #23): looked at on opening and on every change, for this session.
    readonly property var phantoms: Ports.phantoms(ViewState.deviceSightings)
    function sightDevices() { ViewState.deviceSightings = Ports.sight(ViewState.deviceSightings, bluetooth.devices, Date.now()); }
    onPairedChanged: sightDevices()
    Component.onCompleted: sightDevices()
    function recordingTime(seconds) {
        return [Math.floor(seconds / 3600), Math.floor(seconds / 60) % 60, seconds % 60].map(v => String(v).padStart(2, "0")).join(":");
    }
    function percent(level) {
        return level >= 0 ? Math.round((level > 1 ? level / 100 : level) * 100) + "%" : "";
    }
    HostLease { domain: root.audio; feature: "mixer" }
    HostLease { domain: root.power; feature: "brightness" }
    HostLease { domain: root.network; feature: "details" }
    HostLease { domain: root.host.hostActions; feature: "recording" }
    // The Wi-Fi scanner runs only while the nearby list is on screen.
    HostLease { domain: root.network; feature: "scan"; active: root.active && root.page === "nearby" && root.network.wifiEnabled }
    Timer { interval: 1000; repeat: true; running: root.active && root.recording; onTriggered: root.now = Date.now() }
    spacing: 12

    // The application mixer: one meter per stream.
    component MixerList: ListView {
        clip: true
        spacing: 8
        ScrollBar.vertical: ScrollBar {}
        delegate: FMeter {
            required property var modelData
            width: ListView.view.width
            label: modelData.app
            symbol: muted ? "volume_off" : "music_note"
            value: modelData.volume * 100
            muted: modelData.muted
            onMoved: v => root.audio.setVolume(modelData.id, v / 100)
            onIconClicked: root.audio.setMuted(modelData.id, !modelData.muted)
        }
        FText { visible: root.streams.length === 0; text: "nothing is making a sound."; aside: true; color: Design.faint }
    }

    // The hero: the two links.
    RowLayout {
        Layout.fillWidth: true
        spacing: 14
        LinkPlane {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            Layout.preferredHeight: root.linkHeight
            symbol: root.network.kind === "ethernet" ? "lan" : root.network.wifiEnabled ? "wifi" : "wifi_off"
            label: root.network.kind === "ethernet" ? "Wired" : "Wi-Fi"
            on: root.network.wifiEnabled
            line: root.network.connected ? root.network.name : root.network.wifiEnabled ? "Not connected" : "Off"
            detail: root.network.ipAddress
            press: letterpress.item?.press ?? 0
            // Overdrive: the traffic pressed into the plane's name (Letterpress, atlas #73).
            Stratum {
                id: letterpress
                name: "devices.letterpress"
                gpu: false
                scope: root
                wanted: root.active && root.network.connected
                sourceComponent: Letterpress { core: root.shell.core }
            }
            onClicked: root.network.setWifiEnabled(!root.network.wifiEnabled)
        }
        LinkPlane {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            Layout.preferredHeight: root.linkHeight
            symbol: root.bluetooth.enabled ? "bluetooth" : "bluetooth_disabled"
            label: "Bluetooth"
            on: root.bluetooth.enabled
            enabled: root.bluetooth.available
            line: !root.bluetooth.available ? "Unavailable" : root.bluetooth.primary?.name || (root.bluetooth.enabled ? "Nothing connected" : "Off")
            detail: root.percent(root.bluetooth.primary?.battery ?? -1)
            onClicked: root.bluetooth.setEnabled(!root.bluetooth.enabled)
        }
    }

    // The power mode as tabs, ruled, and the small switches.
    GridLayout {
        Layout.fillWidth: true
        columns: root.narrow ? 1 : 2
        columnSpacing: 18
        rowSpacing: 6
        RowLayout {
            Layout.fillWidth: true
            spacing: 2
            FText {
                text: "POWER"
                technical: true
                color: Design.muted
                Layout.rightMargin: 8
            }
            Repeater {
                model: root.power.profiles
                SheetTab {
                    required property string modelData
                    label: root.profileLabels[modelData] ?? modelData
                    selected: root.power.profile === modelData
                    onClicked: root.power.setProfile(modelData)
                }
            }
            // The battery's ledger on the power row (BatteryLedger, atlas #22): a hairline until there are reports.
            BatteryLedger {
                Layout.fillWidth: true
                Layout.leftMargin: 8
                Layout.minimumWidth: 16
                entries: root.weather?.ledger ?? []
            }
        }
        RowLayout {
            spacing: 6
            FButton { symbol: "bedtime"; label: root.narrow ? "" : "Night"; hint: "Night light"; selected: root.power.nightLight; implicitHeight: 32; onClicked: { root.shell.close(); root.power.setNightLight(!root.power.nightLight); } }
            FButton { symbol: root.host.notifications.dnd ? "notifications_off" : "notifications"; label: root.narrow ? "" : "Quiet"; hint: "Do not disturb"; selected: root.host.notifications.dnd; implicitHeight: 32; onClicked: root.host.notifications.setDnd(!root.host.notifications.dnd) }
            FButton { symbol: "coffee"; label: root.narrow ? "" : "Awake"; hint: "Stay awake"; selected: root.power.idleInhibited; implicitHeight: 32; onClicked: root.power.setIdleInhibited(!root.power.idleInhibited) }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: root.narrow ? 18 : 28
        // Sound and light, ruled. Capped, so a wide room gives its width to the mixer column, not to longer sliders.
        ColumnLayout {
            Layout.fillWidth: true
            Layout.maximumWidth: 560
            Layout.fillHeight: true
            spacing: 6
            RowLayout {
                Layout.fillWidth: true
                FText { text: "SOUND & LIGHT"; technical: true; color: Design.muted }
                Hairline { Layout.fillWidth: true; Layout.leftMargin: 8; node: 3 }
            }
            FMeter {
                Layout.fillWidth: true
                label: "Output"; symbol: muted ? "volume_off" : "volume_up"
                enabled: root.audio.output !== null
                value: (root.audio.output?.volume ?? 0) * 100
                muted: root.audio.output?.muted ?? false
                onMoved: v => root.audio.setVolume(root.audio.output.id, v / 100)
                onIconClicked: root.audio.setMuted(root.audio.output.id, !root.audio.output.muted)
            }
            FChoice {
                Layout.fillWidth: true
                Accessible.name: "Output device"
                model: root.sinks.map(d => d.name)
                currentIndex: root.sinks.findIndex(d => d.isDefault)
                onActivated: i => root.audio.setDefault("output", root.sinks[i].id)
                enabled: root.sinks.length > 0
            }
            FMeter {
                Layout.fillWidth: true
                Layout.topMargin: 6
                label: "Microphone"; symbol: muted ? "mic_off" : "mic"
                enabled: root.audio.input !== null
                value: (root.audio.input?.volume ?? 0) * 100
                muted: root.audio.input?.muted ?? false
                onMoved: v => root.audio.setVolume(root.audio.input.id, v / 100)
                onIconClicked: root.audio.setMuted(root.audio.input.id, !root.audio.input.muted)
            }
            FChoice {
                Layout.fillWidth: true
                Accessible.name: "Microphone device"
                model: root.sources.map(d => d.name)
                currentIndex: root.sources.findIndex(d => d.isDefault)
                onActivated: i => root.audio.setDefault("input", root.sources[i].id)
                enabled: root.sources.length > 0
            }
            FMeter {
                Layout.fillWidth: true
                Layout.topMargin: 6
                label: "Display luminance"; symbol: "light_mode"
                enabled: root.power.brightness.available
                value: root.power.brightness.level * 100
                onMoved: v => root.power.setBrightness(v / 100)
            }
            // The spare foot of the column; in Overdrive, the USB buses as wired (BusSchematic, docs/OVERDRIVE.md §38).
            Item {
                id: busFoot
                Layout.fillWidth: true
                Layout.fillHeight: true
                Stratum {
                    anchors.fill: parent
                    anchors.topMargin: 14
                    name: "devices.buses"
                    gpu: false
                    scope: busFoot
                    wanted: root.active && busFoot.height >= 70
                    sourceComponent: BusSchematic {
                        core: root.shell.core
                        bluetooth: root.paired
                        outputs: root.sinks
                        inputs: root.sources
                        streams: root.streams
                    }
                }
            }
        }
        // The mixer as its own column, in a wide room.
        ColumnLayout {
            visible: root.wide
            Layout.preferredWidth: 290
            Layout.maximumWidth: 290
            Layout.fillHeight: true
            spacing: 6
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 28
                FText { text: "MIXER"; technical: true; color: Design.muted }
                Hairline { Layout.fillWidth: true; Layout.leftMargin: 8; node: 3 }
            }
            MixerList {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: 60
                model: root.wide ? root.streams : []
            }
        }
        // The link panel: one page at a time.
        ColumnLayout {
            Layout.preferredWidth: root.narrow ? 245 : 310
            Layout.maximumWidth: root.narrow ? 245 : 310
            Layout.minimumWidth: 0
            Layout.fillHeight: true
            spacing: 6
            RowLayout {
                Layout.fillWidth: true
                spacing: 2
                Repeater {
                    model: (root.wide ? [] : [["mixer", "Mixer"]]).concat([["nearby", "Nearby"], ["paired", "Paired"]])
                    SheetTab {
                        required property var modelData
                        label: modelData[1]
                        selected: root.page === modelData[0]
                        onClicked: root.panel = modelData[0]
                    }
                }
                Item { Layout.fillWidth: true }
            }
            MixerList {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: 60
                visible: root.page === "mixer"
                model: root.page === "mixer" ? root.streams : []
            }
            ListView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: 60
                visible: root.page === "nearby"
                clip: true
                model: root.page === "nearby" ? root.nearby : []
                ScrollBar.vertical: ScrollBar {}
                delegate: LinkRow {
                    required property var modelData
                    width: ListView.view.width
                    label: modelData.ssid
                    strength: modelData.strength > 1 ? modelData.strength / 100 : modelData.strength
                    secured: modelData.secured
                    current: modelData.connected
                    tag: modelData.connected ? "LINKED" : modelData.known ? "KNOWN" : "NEW"
                    // Known networks join here; a new one opens the host's dialog for its password.
                    verb: modelData.connected ? "" : modelData.known ? "join" : "host dialog"
                    onClicked: if (!modelData.connected) root.network.connect(modelData.id)
                }
                FText {
                    visible: root.nearby.length === 0
                    width: parent.width
                    wrapMode: Text.Wrap
                    text: root.network.wifiEnabled ? "listening for networks…" : "wi-fi is off. nothing to hear."
                    aside: true
                    color: Design.faint
                }
            }
            ListView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: 60
                visible: root.page === "paired"
                clip: true
                model: root.page === "paired" ? root.paired.concat(root.phantoms.gone) : []
                ScrollBar.vertical: ScrollBar {}
                delegate: LinkRow {
                    required property var modelData
                    width: ListView.view.width
                    label: modelData.name
                    current: modelData.connected
                    tag: [modelData.connected ? "LINKED" : "", root.percent(modelData.battery ?? -1)].filter(s => s).join(" · ")
                    verb: modelData.phantom ? "" : modelData.connected ? "release" : "connect"
                    lost: modelData.phantom ? modelData.lost : root.phantoms.left[modelData.id] ?? 0
                    gone: !!modelData.phantom
                    enabled: root.bluetooth.enabled && !modelData.phantom
                    onClicked: modelData.connected ? root.bluetooth.disconnect(modelData.id) : root.bluetooth.connect(modelData.id)
                }
                FText {
                    visible: root.paired.length === 0
                    width: parent.width
                    wrapMode: Text.Wrap
                    text: root.bluetooth.enabled ? "no one paired. yet." : "bluetooth is off."
                    aside: true
                    color: Design.faint
                }
            }
            FButton {
                Layout.fillWidth: true
                visible: root.page !== "mixer"
                implicitHeight: 32
                label: root.page === "nearby" ? "All networks…" : "Bluetooth settings…"
                enabled: root.page === "nearby" || root.bluetooth.available
                onClicked: root.openDialog(root.page === "nearby" ? "wifi" : "bluetooth")
            }
        }
    }

    // The foot: capture, recording, the address.
    RowLayout {
        Layout.fillWidth: true
        spacing: 10
        FButton { label: "Capture"; symbol: "screenshot_region"; implicitHeight: 34; onClicked: { root.shell.close(); root.host.hostActions.capture(); } }
        FButton {
            label: root.recording ? "Stop recording" : "Record"
            symbol: root.recording ? "stop_circle" : "screen_record"
            danger: root.recording
            implicitHeight: 34
            onClicked: { root.shell.close(); root.host.hostActions.setRecording(!root.recording); }
        }
        FStatusDot { visible: root.recording; color: Design.recording; pulse: root.recording }
        FText {
            visible: root.recording
            text: "REC " + (root.capture.startedAt > 0 ? root.recordingTime(root.recordedSeconds) : "TIMER UNAVAILABLE")
            technical: true
            color: Design.recording
        }
        Hairline { Layout.fillWidth: true; Layout.leftMargin: 6; Layout.rightMargin: 6; node: 3 }
        FText {
            text: root.network.ipAddress || "NO ADDRESS"
            technical: true
            color: Design.muted
        }
        FButton { label: "Copy IP"; implicitHeight: 30; hint: "Copy IP address"; enabled: root.network.ipAddress !== ""; onClicked: root.host.clipboard.copyText(root.network.ipAddress) }
    }
}
