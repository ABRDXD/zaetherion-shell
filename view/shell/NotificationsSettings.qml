import QtQuick
import QtQuick.Layouts
import qs.core.client
import qs.view.contract
import qs.view.ui

// FART's Notifications tab (Z176, Z207). Everything here is the core's: do-not-disturb (the inbox), how long a
// notification stays on the island (the `island` topic), the two notification sounds (sfx cues), the apps whose
// pictures are never kept (Z170's private apps), and the inbox itself. Our notification server holds them, not DMS
// (Z171), so nothing here is DMS's. No notification's text is shown.
ColumnLayout {
    id: root
    required property CoreClient core
    required property NotificationsDomain notifications
    property bool active: false
    spacing: Design.baseline * 3

    property string error: ""
    function failed(ok, reply) {
        if (!ok || reply?.ok === false)
            root.error = reply?.message || reply?.line || "Could not change that setting";
    }
    function run(line) {
        error = "";
        core.request("cmd.run", {
            line: line,
            record: false
        }, (ok, reply) => root.failed(ok, reply));
    }

    readonly property int noticeMs: core.islandData?.noticeMs ?? 0
    readonly property var cues: core.sfxData?.cues ?? []
    function cueOn(name) {
        return cues.find(c => c.name === name)?.enabled;
    }
    function setCue(name, on) {
        error = "";
        core.request("sfx.configure", {
            cues: {
                [name]: on
            }
        }, (ok, reply) => root.failed(ok, reply));
    }

    // The private apps are read when the tab opens, and again after each change.
    property var privateApps: []
    function readPrivate(apps) {
        core.request("notif.privateApps", apps === undefined ? {} : {
            apps: apps
        }, (ok, reply) => {
            if (ok && Array.isArray(reply?.apps))
                root.privateApps = reply.apps;
            else
                root.failed(ok, reply);
        });
    }
    onActiveChanged: if (active)
        readPrivate()
    Component.onCompleted: if (active)
        readPrivate()
    // Apps seen in the inbox that are not private yet: the ones worth offering.
    readonly property var seenApps: {
        const names = [];
        for (const item of notifications.items) {
            const name = item.appName ?? "";
            if (name && !names.some(n => n.toLowerCase() === name.toLowerCase()) && !privateApps.some(p => p.toLowerCase() === name.toLowerCase()))
                names.push(name);
        }
        return names.sort((a, b) => a.localeCompare(b)).slice(0, 8);
    }

    // ---- Quiet.
    FText {
        text: "QUIET"
        technical: true
        color: Design.accent
    }
    GridLayout {
        Layout.fillWidth: true
        columns: width >= Design.baseline * 110 ? 2 : 1
        columnSpacing: Design.baseline * 8
        rowSpacing: Design.baseline * 5
        SettingChoices {
            Layout.fillWidth: true
            label: "DO NOT DISTURB"
            prominent: true
            note: root.notifications.dnd ? "critical ones still come through" : ""
            enabled: root.notifications.available
            available: root.notifications.available
            options: [[false, "Off"], [true, "On"]]
            value: root.notifications.available ? root.notifications.dnd : undefined
            onPicked: value => root.notifications.setDnd(value)
        }
        SettingChoices {
            Layout.fillWidth: true
            label: "ON THE ISLAND"
            prominent: true
            note: "critical: until dismissed"
            enabled: root.noticeMs > 0
            options: [[1000, "1 s"], [2000, "2 s"], [3000, "3 s"], [5000, "5 s"]]
            value: root.noticeMs > 0 ? root.noticeMs : undefined
            onPicked: value => root.run("island notice " + value / 1000)
        }
        SettingChoices {
            Layout.fillWidth: true
            label: "SOUND"
            enabled: root.cueOn("notify.normal") !== undefined
            options: [[true, "On"], [false, "Off"]]
            value: root.cueOn("notify.normal")
            onPicked: value => root.setCue("notify.normal", value)
        }
        SettingChoices {
            Layout.fillWidth: true
            label: "CRITICAL SOUND"
            note: "even in do-not-disturb"
            enabled: root.cueOn("notify.critical") !== undefined
            options: [[true, "On"], [false, "Off"]]
            value: root.cueOn("notify.critical")
            onPicked: value => root.setCue("notify.critical", value)
        }
    }

    FRule {
        Layout.fillWidth: true
    }

    // ---- Private apps and the inbox, side by side under the grid (one column when narrow), as the grid's own
    // two columns (Z219). While the inbox is offline every action here is off, and the line under says why.
    readonly property bool inboxUp: notifications.available
    GridLayout {
        Layout.fillWidth: true
        columns: width >= Design.baseline * 110 ? 2 : 1
        columnSpacing: Design.baseline * 8
        rowSpacing: Design.baseline * 5
        ColumnLayout {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            Layout.alignment: Qt.AlignTop
            spacing: Design.baseline * 2
            FText { text: "PRIVATE APPS · NO PICTURES KEPT"; technical: true; color: Design.accent }
            FText {
                visible: root.privateApps.length === 0
                text: "None yet"
                technical: true
                font.pixelSize: Design.body
                font.capitalization: Font.MixedCase
            }
            Flow {
                Layout.fillWidth: true
                visible: root.privateApps.length > 0
                spacing: Design.baseline * 4
                Repeater {
                    model: root.privateApps
                    SettingsAction {
                        required property string modelData
                        objectName: "private-" + modelData
                        label: modelData
                        glyph: "×"
                        enabled: root.inboxUp
                        Accessible.description: "Keep pictures from " + modelData + " again"
                        onActivated: root.readPrivate(root.privateApps.filter(app => app !== modelData))
                    }
                }
            }
            Flow {
                Layout.fillWidth: true
                visible: root.seenApps.length > 0
                spacing: Design.baseline * 4
                FText {
                    height: Design.minHit + Design.baseline * 2
                    verticalAlignment: Text.AlignVCenter
                    text: "ADD"
                    technical: true
                    color: Design.muted
                }
                Repeater {
                    model: root.seenApps
                    SettingsAction {
                        required property string modelData
                        objectName: "seen-" + modelData
                        label: modelData
                        glyph: "+"
                        enabled: root.inboxUp
                        Accessible.description: "Keep no pictures from " + modelData
                        onActivated: root.readPrivate(root.privateApps.concat([modelData]))
                    }
                }
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            Layout.alignment: Qt.AlignTop
            spacing: Design.baseline * 2
            FText { text: "INBOX"; technical: true; color: Design.accent }
            FText {
                objectName: "inboxCount"
                text: root.inboxUp ? root.notifications.items.length + " kept · " + root.notifications.unread + " unread" : "Offline"
                technical: true
                font.pixelSize: Design.body
                font.capitalization: Font.MixedCase
                color: root.inboxUp ? Design.ink : Design.muted
            }
            Flow {
                Layout.fillWidth: true
                spacing: Design.baseline * 6
                SettingsAction {
                    objectName: "notifReadAll"
                    label: "Mark all read"
                    enabled: root.inboxUp && root.notifications.unread > 0
                    onActivated: root.notifications.markAllRead()
                }
                SettingsAction {
                    objectName: "notifClear"
                    label: "Clear inbox"
                    armedLabel: "Clear every notification? Confirm"
                    confirm: true
                    enabled: root.inboxUp && root.notifications.items.length > 0
                    onActivated: root.core.request("notif.clear", {}, (ok, reply) => root.failed(ok, reply))
                }
            }
        }
    }
    FText {
        visible: !root.inboxUp && root.error === ""
        text: "The inbox is offline. Its settings come back with it."
        technical: true
        font.capitalization: Font.MixedCase
        color: Design.muted
    }
    FText {
        visible: root.error !== ""
        text: root.error
        technical: true
        color: Design.danger
    }
    Item {
        Layout.fillHeight: true
    }
}
