import qs.view.contract
import qs.view.shell
import qs.view.ui
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ColumnLayout {
    id: root
    required property HostAdapter host
    required property ShellContext shell
    property string selectedApp: ""
    readonly property var inbox: host.notifications
    readonly property var appNames: [...new Set(inbox.items.map(n => n.appName))]
    // While the items are only mirrored from the host's server, its centre still holds their actions and history.
    readonly property bool mirrored: inbox.source === "mirror"
    readonly property int pictureSide: 40
    readonly property var messages: inbox.items.filter(n => selectedApp === "" || n.appName === selectedApp).slice().reverse()
    function timestamp(time) {
        return Qt.formatTime(new Date(time > 1e12 ? time : time * 1000), "HH:mm");
    }
    spacing: 14
    RowLayout {
        Layout.fillWidth: true
        FChoice {
            Layout.preferredWidth: 240
            model: ["All sources", ...root.appNames]
            onActivated: i => root.selectedApp = i ? root.appNames[i - 1] : ""
        }
        Item {
            Layout.fillWidth: true
        }
        FButton {
            label: root.inbox.dnd ? "DND on" : "DND off"
            symbol: root.inbox.dnd ? "notifications_off" : "notifications"
            selected: root.inbox.dnd
            onClicked: root.inbox.setDnd(!root.inbox.dnd)
        }
        FButton {
            label: "Mark read"
            symbol: "done_all"
            onClicked: root.inbox.markAllRead()
        }
    }
    ListView {
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        spacing: 14
        model: root.messages
        ScrollBar.vertical: ScrollBar {}
        section.property: "appName"
        section.criteria: ViewSection.FullString
        section.delegate: FText {
            required property string section
            text: section.toUpperCase()
            technical: true
            color: Design.accent
            height: 28
        }
        delegate: Item {
            id: message
            required property var modelData
            width: ListView.view.width
            height: body.implicitHeight + 24
            Rectangle {
                width: 2
                height: parent.height - 6
                color: message.modelData.urgency === "critical" ? Design.danger : Design.line
            }
            ColumnLayout {
                id: body
                x: 18
                width: parent.width - 18
                spacing: 7
                RowLayout {
                    Layout.fillWidth: true
                    FText {
                        Layout.fillWidth: true
                        text: message.modelData.summary
                        font.pixelSize: Design.readout
                        font.weight: Font.Medium
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                    }
                    FText {
                        text: root.timestamp(message.modelData.time)
                        technical: true
                        color: Design.faint
                    }
                    FButton {
                        symbol: "close"
                        hint: "Dismiss notification"
                        implicitHeight: 28
                        onClicked: root.inbox.dismiss(message.modelData.id)
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12
                    FText {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignTop
                        visible: text !== ""
                        text: message.modelData.body.replace(/<[^>]*>/g, "").slice(0, 2000)
                        wrapMode: Text.Wrap
                        maximumLineCount: 5
                        color: Design.muted
                        font.pixelSize: Design.body
                    }
                    Image {
                        id: picture
                        visible: status === Image.Ready
                        Layout.preferredWidth: root.pictureSide
                        Layout.preferredHeight: root.pictureSide
                        Layout.alignment: Qt.AlignTop
                        source: message.modelData.image ?? ""
                        sourceSize.width: root.pictureSide
                        sourceSize.height: root.pictureSide
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        onStatusChanged: if (status === Image.Ready) root.inbox.keepImage(message.modelData.id, picture)
                    }
                }
                InboxAnswer {
                    Layout.fillWidth: true
                    item: message.modelData
                    inbox: root.inbox
                    onOpenHost: root.shell.openHost("notifications")
                }
            }
        }
        Column {
            anchors.centerIn: parent
            spacing: 12
            visible: root.messages.length === 0
            FText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "—"
                font.pixelSize: Design.display
                font.weight: Font.ExtraLight
                color: Design.faint
            }
            FText {
                text: root.inbox.available ? "NO TRANSMISSIONS" : "USE HOST CENTER"
                font.pixelSize: Design.readout
                color: Design.muted
            }
            FText {
                aside: true
                visible: root.mirrored
                text: "Earlier messages and actions are in the host center."
                font.pixelSize: Design.caption
                color: Design.faint
            }
        }
    }
    // The attention band: sources, arrivals and the silence's debt (AttentionBand; atlas #33–35).
    AttentionBand {
        Layout.fillWidth: true
        Layout.topMargin: 12
        items: root.inbox.items
        active: root.visible && root.shell.panelOpen
    }
    RowLayout {
        FText {
            text: root.inbox.items.length + " RECEIVED · " + root.inbox.unread + " UNREAD"
            technical: true
            color: Design.faint
            Layout.fillWidth: true
        }
        FButton {
            visible: root.mirrored
            label: "Open notification center"
            symbol: "open_in_new"
            onClicked: root.shell.openHost("notifications")
        }
    }
}
