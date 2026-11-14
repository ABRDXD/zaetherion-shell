import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.view.contract
import qs.view.rooms
import qs.view.ui
import "NetWords.js" as Words

// FART's Wi-Fi settings (docs/NET_BT.md §5, Z95, Z176): on/off, nearby networks, join with a password or a hidden
// name, saved networks with auto-join and forget, the wired/Wi-Fi preference, VPN on/off, and NetworkManager's own
// password prompts. Everything shown comes from the network domain; nothing here is optimistic. Typed passwords stay
// in their masked field and are cleared on join, cancel, close and fold; they are never kept anywhere else.
ColumnLayout {
    id: root
    required property NetworkDomain network
    property bool active: false
    // A network to open the join form for (Devices' "join…" on a new network).
    property string prefill: ""
    // The network whose join form is open, or "".
    property string joining: ""
    property bool hiddenForm: false
    spacing: Design.baseline * 3

    HostLease { domain: root.network; feature: "scan"; active: root.active && root.network.wifiEnabled }
    HostLease { domain: root.network; feature: "saved"; active: root.active }
    HostLease { domain: root.network; feature: "details"; active: root.active }

    readonly property var nearby: root.network.networks.slice().sort((a, b) =>
        (b.connected - a.connected) || (b.known - a.known) || (b.strength - a.strength))
    readonly property var current: nearby.find(n => n.connected) ?? null
    // While NetworkManager's prompt for the same network is open, the prompt says it; the line would only repeat it.
    readonly property bool promptSaysIt: root.network.prompt !== null && root.network.prompt.ssid === (root.network.attempt?.target ?? "")
    readonly property var attemptWords: promptSaysIt ? null : Words.attempt(root.network.attempt, root.network.attempt?.target ?? "", "wifi")
    readonly property var vpnWords: {
        const a = root.network.vpnAttempt;
        return Words.attempt(a, root.network.vpns.find(v => v.id === a?.target)?.name ?? "", "vpn");
    }
    readonly property bool busy: promptSaysIt || (attemptWords?.busy ?? false)

    // Secrets leave the screen with the section.
    onActiveChanged: if (!active) closeForms()
    onPrefillChanged: if (prefill !== "") openJoin(prefill)
    function closeForms() { joining = ""; hiddenForm = false; }
    function openJoin(ssid) { hiddenForm = false; joining = ssid; }
    function pick(n) {
        if (n.connected || root.busy) return;
        // A saved network joins at once; an enterprise one is refused by the adapter, with its reason.
        if (n.known || n.enterprise) root.network.connect(n.id);
        else if (!n.secured) root.network.join(n.id, "", false);
        else openJoin(n.id);
    }
    function retry() {
        const a = root.network.attempt;
        if (!a) return;
        root.network.dismissAttempt();
        if (a.action === "join") openJoin(a.target);
        else if (a.action === "connect") root.network.connect(a.target);
        else if (a.action === "forget") root.network.forget(a.target);
        else if (a.action.startsWith("autoconnect:")) root.network.setAutoconnect(a.target, a.action === "autoconnect:on");
    }

    // ---- The strip: on/off, what we're on, wired, preference.
    RowLayout {
        Layout.fillWidth: true
        spacing: Design.baseline * 4
        FToggle {
            objectName: "wifiToggle"
            label: "WI-FI"
            symbol: root.network.wifiEnabled ? "wifi" : "wifi_off"
            selected: root.network.wifiEnabled
            enabled: root.network.available
            onClicked: root.network.setWifiEnabled(!root.network.wifiEnabled)
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
                text: !root.network.available ? "Offline"
                    : root.network.kind === "wifi" ? root.network.name
                    : root.network.connecting !== "" ? "Joining " + root.network.connecting + "…"
                    : root.network.wifiEnabled ? "Not connected" : "Wi-Fi is off"
                color: root.network.kind === "wifi" ? Design.accent : Design.ink
            }
            FText {
                Layout.fillWidth: true
                elide: Text.ElideRight
                technical: true
                color: Design.muted
                text: [root.network.ipAddress, Words.band(root.current?.band ?? ""),
                       root.network.wired.connected ? "WIRED · " + root.network.wired.name : "NO CABLE"].filter(s => s).join("  ·  ")
            }
        }
        FButton {
            visible: root.network.kind === "wifi"
            label: "Leave"
            enabled: !root.busy
            onClicked: root.network.disconnect()
        }
        RowLayout {
            visible: root.network.preference !== ""
            spacing: Design.baseline
            FText { text: "PREFER"; technical: true; color: Design.muted }
            Repeater {
                model: [["auto", "AUTO"], ["wifi", "WI-FI"], ["ethernet", "WIRED"]]
                FButton {
                    required property var modelData
                    objectName: "prefer-" + modelData[0]
                    label: modelData[1]
                    implicitHeight: Design.minHit + Design.baseline * 2
                    selected: root.network.preference === modelData[0]
                    onClicked: root.network.setPreference(modelData[0])
                }
            }
        }
    }

    // ---- What the last action did.
    AttemptBanner {
        objectName: "wifiAttempt"
        words: root.attemptWords
        onRetry: root.retry()
        onDismiss: root.network.dismissAttempt()
    }

    // ---- NetworkManager asks for a password.
    Rectangle {
        objectName: "wifiPrompt"
        visible: root.network.prompt !== null
        Layout.fillWidth: true
        implicitHeight: promptColumn.implicitHeight + Design.baseline * 6
        color: "transparent"
        border.width: 1
        border.color: Design.accent
        ColumnLayout {
            id: promptColumn
            anchors.fill: parent
            anchors.margins: Design.baseline * 3
            spacing: Design.baseline * 2
            FText {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                aside: true
                text: Words.prompt(root.network.prompt)
            }
            SecretRow {
                visible: root.network.prompt?.kind !== "unsupported"
                shown: root.network.prompt !== null && root.active
                action: "Send"
                onSubmitted: secret => root.network.answerPrompt(root.network.prompt.id, secret)
                onCancelled: root.network.cancelPrompt(root.network.prompt.id)
            }
            FButton {
                visible: root.network.prompt?.kind === "unsupported"
                label: "Cancel"
                onClicked: root.network.cancelPrompt(root.network.prompt.id)
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: Design.baseline * 6

        // ---- Nearby.
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: 3
            spacing: Design.baseline
            FText { text: "NEARBY"; technical: true; color: Design.muted }
            ListView {
                id: nearbyList
                objectName: "wifiNearby"
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 0
                model: root.nearby
                ScrollBar.vertical: ScrollBar {}
                delegate: ColumnLayout {
                    id: entry
                    required property var modelData
                    width: ListView.view.width
                    spacing: 0
                    LinkRow {
                        Layout.fillWidth: true
                        label: entry.modelData.ssid
                        strength: entry.modelData.strength
                        secured: entry.modelData.secured
                        current: entry.modelData.connected
                        tag: [entry.modelData.connected ? "LINKED" : entry.modelData.known ? "SAVED" : "",
                              entry.modelData.enterprise ? "ENTERPRISE" : "", Words.band(entry.modelData.band)].filter(s => s).join(" · ")
                        verb: entry.modelData.connected ? "" : entry.modelData.enterprise && !entry.modelData.known ? "unsupported"
                            : entry.modelData.known || !entry.modelData.secured ? "join" : "password…"
                        enabled: !root.busy || entry.modelData.connected
                        onClicked: root.pick(entry.modelData)
                    }
                    SecretRow {
                        Layout.fillWidth: true
                        Layout.topMargin: Design.baseline * 2
                        Layout.bottomMargin: Design.baseline * 2
                        visible: shown
                        shown: root.joining === entry.modelData.id && root.active
                        action: "Join"
                        onSubmitted: secret => { root.joining = ""; root.network.join(entry.modelData.id, secret, false); }
                        onCancelled: root.joining = ""
                    }
                }
                FText {
                    visible: root.nearby.length === 0
                    width: parent.width
                    wrapMode: Text.Wrap
                    aside: true
                    color: Design.faint
                    text: !root.network.available ? "DMS is offline." : root.network.wifiEnabled ? "listening for networks…" : "wi-fi is off. nothing to hear."
                }
            }
            FButton {
                objectName: "joinHidden"
                visible: !root.hiddenForm
                label: "Join a hidden network…"
                enabled: root.network.available && root.network.wifiEnabled && !root.busy
                onClicked: { root.joining = ""; root.hiddenForm = true; hiddenName.forceActiveFocus(); }
            }
            RowLayout {
                visible: root.hiddenForm
                Layout.fillWidth: true
                spacing: Design.baseline * 2
                FField {
                    id: hiddenName
                    Layout.preferredWidth: 180
                    placeholderText: "Network name"
                    inputMethodHints: Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
                }
                SecretRow {
                    Layout.fillWidth: true
                    shown: root.hiddenForm && root.active
                    action: "Join"
                    allowEmpty: true
                    onSubmitted: secret => {
                        const name = hiddenName.text.trim();
                        if (name === "") return;
                        root.hiddenForm = false;
                        hiddenName.text = "";
                        root.network.join(name, secret, true);
                    }
                    onCancelled: { root.hiddenForm = false; hiddenName.text = ""; }
                }
            }
        }

        // ---- Saved, and VPN.
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: 2
            spacing: Design.baseline
            FText { text: "SAVED"; technical: true; color: Design.muted }
            ListView {
                objectName: "wifiSaved"
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                model: root.network.saved
                ScrollBar.vertical: ScrollBar {}
                delegate: RowLayout {
                    id: saved
                    required property var modelData
                    width: ListView.view.width
                    height: Design.minHit + Design.baseline * 5
                    spacing: Design.baseline * 2
                    FStatusDot { color: saved.modelData.inRange ? Design.accent : Design.line }
                    FText {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        font.capitalization: Font.MixedCase
                        text: saved.modelData.ssid
                        color: saved.modelData.connected ? Design.accent : Design.ink
                    }
                    FButton {
                        label: "AUTO-JOIN"
                        hint: saved.modelData.autoconnect ? "Joins by itself when in range" : "Joins only when you pick it"
                        implicitHeight: Design.minHit + Design.baseline * 2
                        selected: saved.modelData.autoconnect
                        enabled: !root.busy
                        onClicked: root.network.setAutoconnect(saved.modelData.id, !saved.modelData.autoconnect)
                    }
                    FConfirmButton {
                        verb: "Forget"
                        implicitHeight: Design.minHit + Design.baseline * 2
                        enabled: !root.busy
                        onConfirmed: root.network.forget(saved.modelData.id)
                    }
                }
                FText {
                    visible: root.network.saved.length === 0
                    width: parent.width
                    aside: true
                    color: Design.faint
                    text: "nothing saved."
                }
            }
            FText { visible: root.network.vpns.length > 0; text: "VPN"; technical: true; color: Design.muted }
            Repeater {
                model: root.network.vpns
                RowLayout {
                    id: vpn
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: Design.baseline * 2
                    FText {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        font.capitalization: Font.MixedCase
                        text: vpn.modelData.name
                        color: vpn.modelData.state === "on" ? Design.accent : Design.ink
                    }
                    FText { technical: true; color: Design.muted; text: vpn.modelData.state.toUpperCase() }
                    FButton {
                        objectName: "vpn-" + vpn.modelData.id
                        label: vpn.modelData.state === "off" ? "Start" : "Stop"
                        implicitHeight: Design.minHit + Design.baseline * 2
                        enabled: !(root.vpnWords?.busy ?? false)
                        onClicked: root.network.setVpn(vpn.modelData.id, vpn.modelData.state === "off")
                    }
                }
            }
            AttemptBanner {
                words: root.vpnWords
                onRetry: { const a = root.network.vpnAttempt; root.network.dismissAttempt(); root.network.setVpn(a.target, a.action === "vpn:on"); }
                onDismiss: root.network.dismissAttempt()
            }
        }
    }

}
