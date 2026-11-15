import QtQuick
import QtQuick.Layouts
import qs.core.client
import qs.view.contract
import qs.view.ui

// FART's Clips settings (Z176, Z184, Z202). Quick paste's own (what Enter does, rows, pictures) are the core's
// `clips` topic; the history's (on, how long, size, auto-clear, pins, clear at startup) are DMS's own clipboard
// config, read under the domain's "config" lease and written straight back to it. No clip content is shown here.
ColumnLayout {
    id: root
    required property CoreClient core
    required property ClipboardDomain clipboard
    property bool active: false
    spacing: Design.baseline * 3

    HostLease { domain: root.clipboard; feature: "config"; active: root.active }
    readonly property var quick: core.clipsData ?? null
    readonly property var history: clipboard.config
    property string error: ""
    function setQuick(key, value) {
        error = "";
        core.request("clips.set", { key: key, value: value }, (ok, reply) => {
            if (!ok) root.error = reply?.message ?? "Could not change that setting";
        });
    }

    // DMS's own choices (its Settings → Clipboard), so nothing here is a value DMS doesn't offer.
    readonly property var keepOptions: [[100, "100"], [200, "200"], [500, "500"], [1000, "1 000"], [10000, "10 000"], [-1, "No limit"]]
    readonly property var sizeOptions: [[1048576, "1 MB"], [5242880, "5 MB"], [20971520, "20 MB"], [52428800, "50 MB"]]
    readonly property var clearOptions: [[0, "Never"], [1, "1 day"], [7, "7 days"], [30, "30 days"], [90, "90 days"]]
    readonly property var pinOptions: [[10, "10"], [25, "25"], [50, "50"], [100, "100"]]

    // ---- Quick paste (Super+V).
    FText { text: "QUICK PASTE · SUPER+V"; technical: true; color: Design.accent }
    SettingChoices {
        Layout.fillWidth: true
        label: "ENTER"
        note: "Shift+Enter: the other"
        enabled: root.quick !== null
        options: [[false, "Copies"], [true, "Pastes"]]
        value: root.quick?.enterPastes
        onPicked: value => root.setQuick("enterPastes", value)
    }
    SettingChoices {
        Layout.fillWidth: true
        label: "ROWS"
        enabled: root.quick !== null
        options: [[4, "4"], [6, "6"], [8, "8"], [10, "10"]]
        value: root.quick?.rows
        onPicked: value => root.setQuick("rows", value)
    }
    SettingChoices {
        Layout.fillWidth: true
        label: "PICTURES"
        enabled: root.quick !== null
        options: [[true, "Shown"], [false, "Hidden"]]
        value: root.quick?.showImages
        onPicked: value => root.setQuick("showImages", value)
    }

    FRule { Layout.fillWidth: true }

    // ---- The history (DMS's).
    FText { text: "HISTORY · KEPT BY DMS"; technical: true; color: Design.accent }
    FText {
        visible: root.history === null
        text: root.clipboard.available ? "Reading DMS's clipboard settings…" : "DMS's clipboard is offline"
        technical: true
        color: Design.muted
    }
    ColumnLayout {
        visible: root.history !== null
        Layout.fillWidth: true
        spacing: Design.baseline * 3
        SettingChoices {
            Layout.fillWidth: true
            label: "RECORDING"
            note: root.history?.disabled ? "Copies are not kept" : ""
            options: [[false, "On"], [true, "Off"]]
            value: root.history?.disabled
            onPicked: value => root.clipboard.setConfig("disabled", value)
        }
        SettingChoices {
            Layout.fillWidth: true
            label: "KEEP"
            note: "entries, pins aside"
            options: root.keepOptions
            value: root.history?.maxHistory
            onPicked: value => root.clipboard.setConfig("maxHistory", value)
        }
        SettingChoices {
            Layout.fillWidth: true
            label: "LARGEST ENTRY"
            options: root.sizeOptions
            value: root.history?.maxEntrySize
            onPicked: value => root.clipboard.setConfig("maxEntrySize", value)
        }
        SettingChoices {
            Layout.fillWidth: true
            label: "AUTO-CLEAR"
            note: "entries older than this"
            options: root.clearOptions
            value: root.history?.autoClearDays
            onPicked: value => root.clipboard.setConfig("autoClearDays", value)
        }
        SettingChoices {
            Layout.fillWidth: true
            label: "PINS"
            note: "at most"
            options: root.pinOptions
            value: root.history?.maxPinned
            onPicked: value => root.clipboard.setConfig("maxPinned", value)
        }
        SettingChoices {
            Layout.fillWidth: true
            label: "AT LOGIN"
            options: [[false, "Keep history"], [true, "Clear history"]]
            value: root.history?.clearAtStartup
            onPicked: value => root.clipboard.setConfig("clearAtStartup", value)
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: Design.baseline * 2
            FText {
                Layout.preferredWidth: 200
                text: "CLEAR NOW"
                technical: true
            }
            FConfirmButton {
                objectName: "clipsClear"
                verb: "Clear history"
                armedVerb: "Clear all but pins?"
                onConfirmed: root.clipboard.clearHistory()
            }
            Item { Layout.fillWidth: true }
        }
    }
    FText {
        visible: root.error !== ""
        text: root.error
        technical: true
        color: Design.danger
    }
    Item { Layout.fillHeight: true }
}
