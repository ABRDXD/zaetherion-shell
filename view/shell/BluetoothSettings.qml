import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.view.contract
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
    spacing: Design.baseline * 3

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
        FToggle {
            objectName: "btToggle"
            label: "BLUETOOTH"
            symbol: root.bluetooth.enabled ? "bluetooth" : "bluetooth_disabled"
            selected: root.bluetooth.enabled
            enabled: root.bluetooth.available
            onClicked: root.bluetooth.setEnabled(!root.bluetooth.enabled)
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: Design.baseline
            FText {
                Layout.fillWidth: true
                elide: Text.ElideRight
                headline: true
                font.capitalization: Font.MixedCase
                font.pixelSize: Design.readout
                readonly property int linked: root.bluetooth.devices.filter(d => d.connected).length
                text: !root.bluetooth.available ? "Offline" : !root.bluetooth.enabled ? "Bluetooth is off"
                    : linked === 0 ? "Nothing connected" : linked === 1 ? root.bluetooth.primary?.name ?? "1 connected" : linked + " connected"
                color: linked > 0 ? Design.accent : Design.ink
            }
            FText {
                technical: true
                color: Design.muted
                text: root.bluetooth.discovering ? "SCANNING" : root.bluetooth.devices.length + " PAIRED"
            }
        }
        FButton {
            objectName: "btScan"
            label: root.scanning ? "Stop scanning" : "Scan for devices"
            symbol: "radar"
            selected: root.scanning
            enabled: root.bluetooth.available && root.bluetooth.enabled
            onClicked: root.scanning = !root.scanning
        }
    }

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
            FText {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                aside: true
                text: root.asking?.line ?? ""
            }
            FText {
                visible: (root.bluetooth.pairing?.passkey ?? "") !== ""
                text: root.bluetooth.pairing?.passkey ?? ""
                font.pixelSize: Design.figure
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
                FButton {
                    visible: (root.asking?.yes ?? "") !== ""
                    label: root.asking?.yes ?? ""
                    primary: true
                    onClicked: root.bluetooth.answerPairing(root.bluetooth.pairing.id, "")
                }
                FButton { label: root.asking?.no ?? "Cancel"; onClicked: root.bluetooth.cancelPairing(root.bluetooth.pairing.id) }
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: Design.baseline * 6

        // ---- Paired: connected first, then audio (the domain's order).
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: 3
            spacing: Design.baseline
            FText { text: "PAIRED"; technical: true; color: Design.muted }
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
                        spacing: Design.baseline * 2
                        FButton {
                            label: modelData.connected ? "Disconnect" : "Connect"
                            implicitHeight: Design.minHit + Design.baseline * 2
                            enabled: root.bluetooth.enabled && !root.busy(modelData.id)
                            onClicked: modelData.connected ? root.bluetooth.disconnect(modelData.id) : root.bluetooth.connect(modelData.id)
                        }
                        FButton {
                            label: "TRUSTED"
                            hint: modelData.trusted ? "Connects without asking" : "Asks before it connects"
                            implicitHeight: Design.minHit + Design.baseline * 2
                            selected: modelData.trusted
                            enabled: root.bluetooth.enabled && !root.busy(modelData.id)
                            onClicked: root.bluetooth.trust(modelData.id, !modelData.trusted)
                        }
                        FConfirmButton {
                            verb: "Forget"
                            implicitHeight: Design.minHit + Design.baseline * 2
                            enabled: root.bluetooth.available && !root.busy(modelData.id)
                            onConfirmed: root.bluetooth.forget(modelData.id)
                        }
                    }
                }
                FText {
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
            spacing: Design.baseline
            FText { text: "NEARBY"; technical: true; color: Design.muted }
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
                    FButton {
                        label: "Pair"
                        implicitHeight: Design.minHit + Design.baseline * 2
                        enabled: root.bluetooth.enabled && !root.busy(modelData.id) && root.bluetooth.pairing === null
                        onClicked: root.bluetooth.pair(modelData.id)
                    }
                }
                FText {
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
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: Design.minHit + Design.baseline * 5
            spacing: Design.baseline * 2
            MaterialSymbol {
                text: row.device.kind ?? "bluetooth"
                iconSize: Design.readout
                color: row.device.connected ? Design.accent : Design.ink
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                FText {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    font.capitalization: Font.MixedCase
                    text: row.device.name ?? ""
                    color: row.device.connected ? Design.accent : Design.ink
                }
                FText {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    technical: true
                    color: Design.muted
                    text: [row.device.connected ? "LINKED" : "", row.device.audio ? "AUDIO" : "",
                           Words.percent(row.device.battery ?? -1)].filter(s => s).join(" · ")
                }
            }
            RowLayout { id: slot; spacing: Design.baseline * 2 }
        }
        AttemptBanner {
            words: root.words(row.device.id)
            onRetry: root.retry(row.device.id)
            onDismiss: root.bluetooth.dismissAttempt(row.device.id)
        }
        Hairline { Layout.fillWidth: true; color: Design.line }
    }
}
