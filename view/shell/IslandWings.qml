import QtQuick
import qs.view.contract
import qs.view.ui

Item {
    id: root
    required property HostAdapter host
    required property real centreWidth
    signal openDevices()
    signal openTray(string itemId)
    readonly property real wingWidth: Math.max(0, (width - centreWidth) / 2)
    readonly property var audio: host.audio
    readonly property var status: [
        { glyph: host.network.connected ? (host.network.kind === "ethernet" ? "lan" : "wifi") : "wifi_off",
            label: "Network", shown: host.network.available },
        { glyph: host.bluetooth.enabled ? "bluetooth" : "bluetooth_disabled", label: "Bluetooth", shown: host.bluetooth.available },
        { glyph: audio.output?.muted ? "volume_off" : "volume_up", label: "Volume", shown: !!audio.output },
        { glyph: audio.input?.muted ? "mic_off" : "mic", label: "Microphone", shown: !!audio.input },
        { glyph: "keyboard_capslock", label: "Caps Lock", shown: host.keybinds.capsLock === true },
        { glyph: "pin", label: "Num Lock", shown: host.keybinds.numLock === true },
        { glyph: "flight", label: "Airplane mode", shown: host.network.airplaneMode === true },
        { glyph: "speed", label: host.power.profile, shown: host.power.available && host.power.profile !== "" }
    ].filter(entry => entry.shown)

    HostLease { domain: root.host.audio; feature: "mixer"; active: root.visible }

    Item {
        width: root.wingWidth
        height: parent.height
        clip: true

        Row {
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            spacing: Design.baseline
            Repeater {
                model: root.status
                IslandGlyph {
                    required property var modelData
                    glyph: modelData.glyph
                    description: modelData.label
                    onClicked: root.openDevices()
                }
            }
        }
    }

    Item {
        anchors.right: parent.right
        width: root.wingWidth
        height: parent.height
        clip: true

        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: Design.baseline * 2
            Row {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.host.weather.available && !!root.host.weather.current
                spacing: Design.baseline
                MaterialSymbol {
                    text: root.host.weather.current?.icon ?? ""
                    iconSize: Design.readout
                    color: Design.ink
                }
                FText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.host.weather.current ? Math.round(root.host.weather.current.tempC) + "°C" : ""
                    technical: true
                }
            }
            Repeater {
                model: root.host.tray.available ? root.host.tray.items : []
                IslandGlyph {
                    required property var modelData
                    glyph: "apps"
                    imageSource: modelData.icon ?? ""
                    description: modelData.title
                    onClicked: modelData.hasMenu ? root.openTray(modelData.id) : root.host.tray.activate(modelData.id)
                }
            }
        }
    }
}
