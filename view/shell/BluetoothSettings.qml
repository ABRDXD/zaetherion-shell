import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.view.contract
import qs.view.fluid
import qs.view.ui
import "NetWords.js" as Words

// FART's Bluetooth settings (docs/NET_BT.md §5, Z95, Z176): on/off, scan, pair (with BlueZ's passkey, PIN and
// confirmation prompts), connect and disconnect, trust, forget, battery and device glyphs, audio devices first.
// Everything shown comes from the Bluetooth domain; a PIN typed here goes straight to it and is cleared at once.
ColumnLayout {
    id: root
    required property BluetoothDomain bluetooth
    property bool active: false
    property bool scanning: false
    spacing: Design.fluid ? FluidTokens.gap : Design.baseline * 3

    HostLease { domain: root.bluetooth; feature: "scan"; active: root.active && root.scanning && root.bluetooth.enabled }
    onActiveChanged: if (!active) scanning = false

    readonly property var asking: Words.pairing(root.bluetooth.pairing)
    function nameOf(id) {
        return (root.bluetooth.devices.find(d => d.id === id) ?? root.bluetooth.nearby.find(d => d.id === id))?.name ?? "";
    }
    function words(id) {
        return Words.attempt(root.bluetooth.attempts[id] ?? null, nameOf(id), "bt");
    }
    function busy(id) {
        return words(id)?.busy ?? false;
    }
    function retry(id) {
        const a = root.bluetooth.attempts[id];
        if (!a) return;
        root.bluetooth.dismissAttempt(id);
        if (a.action === "connect") root.bluetooth.connect(id);
        else if (a.action === "disconnect") root.bluetooth.disconnect(id);
        else if (a.action === "pair") root.bluetooth.pair(id);
        else if (a.action === "forget") root.bluetooth.forget(id);
        else if (a.action.startsWith("trust:")) root.bluetooth.trust(id, a.action === "trust:on");
    }
    // Attempts for devices no longer in either list (a forgotten one), so their outcome is still read.
    readonly property var orphans: Object.keys(root.bluetooth.attempts).filter(id =>
        !root.bluetooth.devices.some(d => d.id === id) && !root.bluetooth.nearby.some(d => d.id === id))

    // ---- The strip.
    RowLayout {
        Layout.fillWidth: true
        spacing: Design.baseline * 4
        FluidText {
            visible: Design.fluid
            Layout.fillWidth: true
            text: "Bluetooth"
            font.pixelSize: FluidTokens.title
            font.weight: Font.DemiBold
        }
        LimbSwitch {
            visible: Design.fluid
            objectName: visible ? "btToggle" : ""
            label: "Bluetooth"
            selected: root.bluetooth.enabled
            enabled: root.bluetooth.available
            onClicked: root.bluetooth.setEnabled(!root.bluetooth.enabled)
        }
        FToggle {
            visible: !Design.fluid
            objectName: visible ? "btToggle" : ""
            label: "BLUETOOTH"
            symbol: root.bluetooth.enabled ? "bluetooth" : "bluetooth_disabled"
            selected: root.bluetooth.enabled
            enabled: root.bluetooth.available
            onClicked: root.bluetooth.setEnabled(!root.bluetooth.enabled)
        }
        ColumnLayout {
            visible: !Design.fluid
            Layout.fillWidth: true
            spacing: Design.baseline
            SettingsText {
                Layout.fillWidth: true
                elide: Text.ElideRight
                headline: true
                font.capitalization: Font.MixedCase
                font.pixelSize: Design.fluid ? FluidTokens.title : Design.figure
                readonly property int linked: root.bluetooth.devices.filter(d => d.connected).length
                text: !root.bluetooth.available ? "Offline" : !root.bluetooth.enabled ? "Bluetooth is off"
                    : linked === 0 ? "Nothing connected" : linked === 1 ? root.bluetooth.primary?.name ?? "1 connected" : linked + " connected"
                color: linked > 0 ? Design.accent : Design.ink
            }
            SettingsText {
                technical: true
                color: Design.muted
                text: root.bluetooth.discovering ? "SCANNING" : root.bluetooth.devices.length + " PAIRED"
            }
        }
        ScanButton { visible: !Design.fluid }
    }
    component ScanButton: SettingsButton {
        objectName: visible ? "btScan" : ""
        label: root.scanning ? "Stop scanning" : "Scan for devices"
        symbol: "radar"
        selected: root.scanning
        enabled: root.bluetooth.available && root.bluetooth.enabled
        onClicked: root.scanning = !root.scanning
    }
    Hairline { endNode: !Design.fluid; Layout.fillWidth: true; visible: Design.fluid; color: FluidTokens.rule }

    // ---- BlueZ asks something while pairing.
    Rectangle {
        objectName: "btPairing"
        visible: root.asking !== null
        Layout.fillWidth: true
        implicitHeight: askColumn.implicitHeight + Design.baseline * 6
        color: "transparent"
        border.width: 1
        border.color: Design.accent
        ColumnLayout {
            id: askColumn
            anchors.fill: parent
            anchors.margins: Design.baseline * 3
            spacing: Design.baseline * 2
            SettingsText {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                aside: true
                text: root.asking?.line ?? ""
            }
            SettingsText {
                visible: (root.bluetooth.pairing?.passkey ?? "") !== ""
                text: root.bluetooth.pairing?.passkey ?? ""
                font.pixelSize: Design.fluid ? FluidTokens.title : Design.figure
                font.letterSpacing: Design.baseline
                color: Design.accent
            }
            SecretRow {
                Layout.fillWidth: true
                visible: (root.asking?.field ?? "") !== ""
                shown: visible && root.active
                placeholder: root.asking?.field ?? ""
                digits: root.bluetooth.pairing?.kind === "passkey"
                action: root.asking?.yes ?? "Pair"
                onSubmitted: code => root.bluetooth.answerPairing(root.bluetooth.pairing.id, code)
                onCancelled: root.bluetooth.cancelPairing(root.bluetooth.pairing.id)
            }
            RowLayout {
                visible: (root.asking?.field ?? "") === ""
                spacing: Design.baseline * 2
                SettingsButton {
                    visible: (root.asking?.yes ?? "") !== ""
                    label: root.asking?.yes ?? ""
                    primary: true
                    onClicked: root.bluetooth.answerPairing(root.bluetooth.pairing.id, "")
                }
                SettingsButton { label: root.asking?.no ?? "Cancel"; onClicked: root.bluetooth.cancelPairing(root.bluetooth.pairing.id) }
            }
        }
    }

    GridLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        columns: Design.fluid ? 1 : 2
        columnSpacing: Design.baseline * 6
        rowSpacing: FluidTokens.gap

        // ---- Paired: connected first, then audio (the domain's order).
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: 3
            Layout.preferredHeight: Design.fluid ? 1 : -1
            Layout.verticalStretchFactor: Design.fluid ? 1 : -1
            spacing: Design.fluid ? FluidTokens.gap : Design.baseline
            SettingsText { visible: !Design.fluid; text: "PAIRED"; technical: true; color: Design.muted }
            RowLayout {
                visible: Design.fluid
                Layout.fillWidth: true
                FluidText { Layout.fillWidth: true; text: "Paired"; font.pixelSize: FluidTokens.heading }
                FluidText { text: root.bluetooth.devices.length + " paired"; color: FluidTokens.secondary }
            }
            ListView {
                objectName: "btPaired"
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                model: root.bluetooth.devices
                ScrollBar.vertical: ScrollBar {}
                delegate: DeviceRow {
                    required property var modelData
                    width: ListView.view.width
                    device: modelData
                    RowLayout {
                        Layout.fillWidth: Design.fluid
                        spacing: Design.baseline * 2
                        SettingsButton {
                            label: modelData.connected ? "Disconnect" : "Connect"
                            Layout.preferredHeight: Design.fluid ? FluidTokens.controlHeight : Design.minHit + Design.baseline * 2
                            enabled: root.bluetooth.enabled && !root.busy(modelData.id)
                            onClicked: modelData.connected ? root.bluetooth.disconnect(modelData.id) : root.bluetooth.connect(modelData.id)
                        }
                        SettingsButton {
                            label: Design.fluid ? (modelData.trusted ? "✓  Trusted" : "Trust") : "TRUSTED"
                            hint: modelData.trusted ? "Connects without asking" : "Asks before it connects"
                            Layout.preferredHeight: Design.fluid ? FluidTokens.controlHeight : Design.minHit + Design.baseline * 2
                            selected: modelData.trusted === true
                            enabled: root.bluetooth.enabled && !root.busy(modelData.id)
                            onClicked: root.bluetooth.trust(modelData.id, !modelData.trusted)
                        }
                        Item { visible: Design.fluid; Layout.fillWidth: true }
                        SettingsAction {
                            visible: Design.fluid
                            label: "Forget…"
                            armedLabel: "Forget?"
                            confirm: true
                            danger: true
                            glyph: ""
                            enabled: root.bluetooth.available && !root.busy(modelData.id)
                            onActivated: root.bluetooth.forget(modelData.id)
                        }
                        FConfirmButton {
                            visible: !Design.fluid
                            verb: "Forget"
                            danger: true
                            Layout.preferredHeight: Design.fluid ? FluidTokens.controlHeight : Design.minHit + Design.baseline * 2
                            enabled: root.bluetooth.available && !root.busy(modelData.id)
                            onConfirmed: root.bluetooth.forget(modelData.id)
                        }
                    }
                }
                SettingsText {
                    visible: root.bluetooth.devices.length === 0
                    width: parent.width
                    aside: true
                    color: Design.faint
                    text: !root.bluetooth.available ? "DMS is offline." : root.bluetooth.enabled ? "no one paired. yet." : "bluetooth is off."
                }
            }
            Repeater {
                model: root.orphans
                AttemptBanner {
                    required property var modelData
                    words: root.words(modelData)
                    onRetry: root.retry(modelData)
                    onDismiss: root.bluetooth.dismissAttempt(modelData)
                }
            }
        }

        // ---- Nearby, while scanning.
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: 2
            Layout.preferredHeight: Design.fluid ? 1 : -1
            Layout.verticalStretchFactor: Design.fluid ? 1 : -1
            spacing: Design.fluid ? FluidTokens.gap : Design.baseline
            Hairline { endNode: !Design.fluid; Layout.fillWidth: true; visible: Design.fluid; color: FluidTokens.rule }
            SettingsText { visible: !Design.fluid; text: "NEARBY"; technical: true; color: Design.muted }
            RowLayout {
                visible: Design.fluid
                Layout.fillWidth: true
                FluidText { Layout.fillWidth: true; text: "Nearby"; font.pixelSize: FluidTokens.heading }
                ScanButton {}
            }
            FluidText {
                visible: Design.fluid && root.bluetooth.discovering
                text: "Scanning for devices"
                color: FluidTokens.secondary
            }
            ListView {
                objectName: "btNearby"
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                model: root.scanning ? root.bluetooth.nearby : []
                ScrollBar.vertical: ScrollBar {}
                delegate: DeviceRow {
                    required property var modelData
                    width: ListView.view.width
                    device: modelData
                    SettingsButton {
                        label: "Pair"
                        Layout.preferredHeight: Design.fluid ? FluidTokens.controlHeight : Design.minHit + Design.baseline * 2
                        enabled: root.bluetooth.enabled && !root.busy(modelData.id) && root.bluetooth.pairing === null
                        onClicked: root.bluetooth.pair(modelData.id)
                    }
                }
                SettingsText {
                    visible: !root.scanning || root.bluetooth.nearby.length === 0
                    width: parent.width
                    wrapMode: Text.Wrap
                    aside: true
                    color: Design.faint
                    text: root.scanning ? "looking for devices… put yours in pairing mode." : "scan to find new devices."
                }
            }
        }
    }

    // One device: glyph, name, what it is, battery; its controls go in `data`; under it, its last action.
    component DeviceRow: ColumnLayout {
        id: row
        property var device: ({})
        default property alias controls: slot.data
        spacing: Design.baseline
        GridLayout {
            Layout.fillWidth: true
            columns: Design.fluid && row.device.paired ? 2 : 3
            columnSpacing: Design.fluid ? FluidTokens.gap : Design.baseline * 2
            rowSpacing: FluidTokens.unit
            Rectangle {
                implicitWidth: Design.fluid ? 40 : Design.readout
                implicitHeight: Design.fluid ? 40 : Design.minHit + Design.baseline * 5
                radius: width / 2
                color: Design.fluid ? Qt.tint(FluidTokens.base, Qt.alpha(FluidTokens.accent, 0.12)) : "transparent"
                MaterialSymbol {
                    anchors.centerIn: parent
                    text: row.device.kind ?? "bluetooth"
                    iconSize: Design.readout
                    color: row.device.connected ? Design.accent : Design.ink
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                SettingsText {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    font.capitalization: Font.MixedCase
                    font.pixelSize: Design.fluid ? FluidTokens.heading : Design.body
                    text: row.device.name ?? ""
                    color: Design.fluid ? FluidTokens.ink : row.device.connected ? Design.accent : Design.ink
                }
                SettingsText {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    technical: true
                    color: Design.muted
                    font.capitalization: Design.fluid ? Font.MixedCase : Font.AllUppercase
                    text: Design.fluid ? [row.device.connected ? "Connected" : row.device.paired ? "Paired" : "Available to pair",
                        row.device.battery >= 0 ? Words.percent(row.device.battery) + " battery" : ""].filter(Boolean).join(" · ")
                        : [row.device.connected ? "LINKED" : "", row.device.audio ? "AUDIO" : "",
                           Words.percent(row.device.battery ?? -1)].filter(s => s).join(" · ")
                }
            }
            RowLayout {
                id: slot
                Layout.fillWidth: Design.fluid && row.device.paired
                Layout.columnSpan: Design.fluid && row.device.paired ? 2 : 1
                Layout.leftMargin: Design.fluid && row.device.paired ? 40 + FluidTokens.gap : 0
                spacing: Design.baseline * 2
            }
        }
        AttemptBanner {
            words: root.words(row.device.id)
            onRetry: root.retry(row.device.id)
            onDismiss: root.bluetooth.dismissAttempt(row.device.id)
        }
        Hairline { endNode: !Design.fluid; Layout.fillWidth: true; color: Design.line }
    }
}
