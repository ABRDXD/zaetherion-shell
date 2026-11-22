import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.view.contract
import qs.view.fluid
import qs.view.ui
import "NetWords.js" as Words

// FART's Bluetooth settings (docs/NET_BT.md §5, Z95, Z176): on/off, scan, pair (with BlueZ's passkey, PIN and
// confirmation prompts), connect and disconnect, trust, forget, battery, audio devices first. Laid out as Side
// column (owner's pick B, 22 November 2026; Z223): each reading on the left, its actions in one right-hand column.
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
    function status(device) {
        return [device.connected ? "Connected" : device.paired ? "Paired" : "Available to pair",
                device.audio && !Design.fluid ? "Audio" : "",
                device.battery >= 0 ? Words.percent(device.battery) + " battery" : ""].filter(Boolean).join(" · ");
    }

    // ---- The strip: the title and the power state.
    RowLayout {
        Layout.fillWidth: true
        spacing: Design.baseline * 4
        Heading { Layout.fillWidth: true; text: "Bluetooth" }
        LimbSwitch {
            visible: Design.fluid
            objectName: visible ? "btToggle" : ""
            label: "Bluetooth"
            selected: root.bluetooth.enabled
            enabled: root.bluetooth.available
            onClicked: root.bluetooth.setEnabled(!root.bluetooth.enabled)
        }
        SettingsAction {
            visible: !Design.fluid
            objectName: visible ? "btToggle" : ""
            label: !root.bluetooth.available ? "Offline" : root.bluetooth.enabled ? "●  On" : "○  Off"
            glyph: ""
            underline: false
            lit: root.bluetooth.enabled
            enabled: root.bluetooth.available
            Accessible.name: "Bluetooth " + (root.bluetooth.enabled ? "on" : "off")
            onActivated: root.bluetooth.setEnabled(!root.bluetooth.enabled)
        }
    }
    Hairline { endNode: false; Layout.fillWidth: true; color: Design.fluid ? FluidTokens.rule : Design.line }

    // ---- BlueZ asks something while pairing.
    ColumnLayout {
        objectName: "btPairing"
        visible: root.asking !== null
        Layout.fillWidth: true
        spacing: Design.baseline
        Caption { text: "Bluetooth pairing" }
        Heading { Layout.fillWidth: true; text: root.asking?.title ?? "" }
        Hairline { endNode: false; Layout.fillWidth: true; color: Design.fluid ? FluidTokens.rule : Design.line }
        Detail { Layout.fillWidth: true; wrapMode: Text.Wrap; text: root.asking?.line ?? "" }
        SettingsText {
            visible: (root.bluetooth.pairing?.passkey ?? "") !== ""
            text: root.bluetooth.pairing?.passkey ?? ""
            font.pixelSize: Design.fluid ? FluidTokens.title : Design.figure
            font.letterSpacing: Design.baseline
            color: Design.accent
        }
        SecretRow {
            Layout.fillWidth: true
            Layout.topMargin: Design.baseline * 2
            visible: (root.asking?.field ?? "") !== ""
            shown: visible && root.active
            placeholder: root.asking?.field ?? ""
            digits: root.bluetooth.pairing?.kind === "passkey"
            action: root.asking?.yes ?? "Pair"
            onSubmitted: code => root.bluetooth.answerPairing(root.bluetooth.pairing.id, code)
            onCancelled: root.bluetooth.cancelPairing(root.bluetooth.pairing.id)
        }
        SettingsSideRow {
            Layout.fillWidth: true
            visible: (root.asking?.field ?? "") === ""
            Detail { text: root.bluetooth.pairing?.deviceName ?? "" }
            actions: [
                SettingsAction {
                    visible: (root.asking?.yes ?? "") !== ""
                    label: root.asking?.yes ?? ""
                    leads: true
                    underline: false
                    onActivated: root.bluetooth.answerPairing(root.bluetooth.pairing.id, "")
                },
                SettingsAction {
                    label: root.asking?.no ?? "Cancel"
                    glyph: ""
                    underline: false
                    onActivated: root.bluetooth.cancelPairing(root.bluetooth.pairing.id)
                }
            ]
        }
    }

    // ---- Paired: connected first, then audio (the domain's order).
    ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredHeight: 3
        Layout.verticalStretchFactor: 3
        spacing: Design.baseline
        Caption { text: "Paired" }
        ListView {
            objectName: "btPaired"
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: root.bluetooth.devices
            ScrollBar.vertical: ScrollBar {}
            delegate: DeviceRow {
                id: paired
                required property var modelData
                width: ListView.view.width
                device: modelData
                actions: [
                    GridLayout {
                        Layout.fillWidth: true
                        columns: 2
                        columnSpacing: Design.baseline * 3
                        rowSpacing: 0
                        SettingsAction {
                            label: paired.modelData.connected ? "Disconnect" : "Connect"
                            leads: true
                            underline: false
                            enabled: root.bluetooth.enabled && !root.busy(paired.modelData.id)
                            onActivated: paired.modelData.connected ? root.bluetooth.disconnect(paired.modelData.id) : root.bluetooth.connect(paired.modelData.id)
                        }
                        SettingsAction {
                            Layout.alignment: Qt.AlignRight
                            label: paired.modelData.trusted ? "✓  Trusted" : "Trust"
                            glyph: ""
                            underline: false
                            lit: paired.modelData.trusted === true
                            enabled: root.bluetooth.enabled && !root.busy(paired.modelData.id)
                            Accessible.description: paired.modelData.trusted ? "Connects without asking" : "Asks before it connects"
                            onActivated: root.bluetooth.trust(paired.modelData.id, !paired.modelData.trusted)
                        }
                        Item { Layout.fillWidth: true }
                        SettingsAction {
                            Layout.alignment: Qt.AlignRight
                            label: "Forget…"
                            armedLabel: "Forget?"
                            confirm: true
                            danger: true
                            glyph: ""
                            underline: false
                            enabled: root.bluetooth.available && !root.busy(paired.modelData.id)
                            onActivated: root.bluetooth.forget(paired.modelData.id)
                        }
                    }
                ]
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

    // ---- Nearby: the scan, then what it finds.
    ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredHeight: 2
        Layout.verticalStretchFactor: 2
        spacing: Design.baseline
        SettingsSideRow {
            Layout.fillWidth: true
            Caption { text: "Nearby" }
            Detail { text: root.bluetooth.discovering ? "Scanning for devices" : root.scanning ? "Starting the scan" : "Not scanning" }
            actions: [
                SettingsAction {
                    objectName: "btScan"
                    Layout.alignment: Qt.AlignRight
                    label: root.scanning ? "Stop scanning" : "Scan for devices"
                    glyph: ""
                    underline: false
                    enabled: root.bluetooth.available && root.bluetooth.enabled
                    onActivated: root.scanning = !root.scanning
                }
            ]
        }
        Hairline { endNode: false; Layout.fillWidth: true; color: Design.fluid ? FluidTokens.rule : Design.line }
        ListView {
            objectName: "btNearby"
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: root.scanning ? root.bluetooth.nearby : []
            ScrollBar.vertical: ScrollBar {}
            delegate: DeviceRow {
                id: found
                required property var modelData
                width: ListView.view.width
                device: modelData
                actions: [
                    SettingsAction {
                        label: "Pair"
                        leads: true
                        underline: false
                        enabled: root.bluetooth.enabled && !root.busy(found.modelData.id) && root.bluetooth.pairing === null
                        onActivated: root.bluetooth.pair(found.modelData.id)
                    }
                ]
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

    // One device: its name and state on the left, its actions in the right column; under it, its last action.
    component DeviceRow: ColumnLayout {
        id: row
        property var device: ({})
        property alias actions: side.actions
        spacing: Design.baseline
        SettingsSideRow {
            id: side
            Layout.fillWidth: true
            Layout.topMargin: Design.baseline * 2
            SettingsText {
                Layout.fillWidth: true
                elide: Text.ElideRight
                font.capitalization: Font.MixedCase
                font.family: Design.fluid ? FluidTokens.sans : Design.sans
                font.pixelSize: Design.fluid ? FluidTokens.heading : Design.readout
                font.weight: Design.fluid ? Font.Normal : Font.Bold
                font.letterSpacing: 0
                text: row.device.name ?? ""
                color: Design.ink
            }
            Detail { Layout.fillWidth: true; elide: Text.ElideRight; text: root.status(row.device) }
        }
        AttemptBanner {
            words: root.words(row.device.id)
            onRetry: root.retry(row.device.id)
            onDismiss: root.bluetooth.dismissAttempt(row.device.id)
        }
        Hairline { endNode: false; Layout.fillWidth: true; color: Design.fluid ? FluidTokens.rule : Design.line }
    }
    // The type roles of a Side column section.
    component Heading: SettingsText {
        elide: Text.ElideRight
        headline: !Design.fluid
        font.capitalization: Font.MixedCase
        font.pixelSize: Design.fluid ? FluidTokens.title : Design.figure
        font.weight: Design.fluid ? Font.Normal : Font.Bold
    }
    component Caption: SettingsText {
        technical: !Design.fluid
        font.capitalization: Design.fluid ? Font.MixedCase : Font.AllUppercase
        font.pixelSize: Design.fluid ? FluidTokens.caption : Design.caption
        color: Design.muted
    }
    component Detail: SettingsText {
        technical: !Design.fluid
        font.capitalization: Font.MixedCase
        font.pixelSize: Design.fluid ? FluidTokens.body : Design.body
        color: Design.muted
    }
}
