import qs.view.contract
import qs.view.shell
import qs.view.ui
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "InboxSky.js" as Sky

// The Inbox as the day's sky (Z211, owner's pick "C · The comets", 16 November 2026). Each notification is a comet
// at the time it came: high when urgent, low when quiet, a tail and a glow while unread, warm when critical. NOW is
// the right edge. Clicking a comet reads it in the panel below: its app and time, the summary large, the body and
// picture, then its actions or reply (InboxAnswer) and Dismiss. The panel starts on the newest unread. The unread
// count is the room's one number. Under it all, the attention band (AttentionBand) and the totals.
ColumnLayout {
    id: root
    required property HostAdapter host
    required property ShellContext shell
    readonly property var inbox: host.notifications
    readonly property var items: inbox.items
    // While the items are only mirrored from the host's server, its centre still holds their actions and history.
    readonly property bool mirrored: inbox.source === "mirror"
    readonly property int pictureSide: 40
    // The notice in the reading panel: the one clicked while it exists, else the newest unread, else the newest.
    property string selectedId: ""
    readonly property var selected: items.find(n => n.id === selectedId) ?? items.find(n => n.id === Sky.initial(items)) ?? null
    readonly property int unread: items.filter(n => !n.read).length
    // The sky's clock moves once a minute (Clock.minuteStr), never per frame.
    readonly property double now: { Clock.minuteStr; return Date.now(); }
    readonly property var sky: Sky.span(items, now)
    function timestamp(time) {
        return Qt.formatTime(new Date(Sky.ms(time)), "HH:mm");
    }
    spacing: 14

    // The one number, and the room's two switches.
    RowLayout {
        Layout.fillWidth: true
        spacing: 18
        FText {
            text: String(root.unread).padStart(2, "0")
            headline: true
            font.pixelSize: Design.display
            font.weight: Font.Black
            font.letterSpacing: -5
        }
        ColumnLayout {
            Layout.alignment: Qt.AlignBottom
            Layout.bottomMargin: 12
            spacing: 4
            FText { text: root.inbox.dnd ? "UNREAD · QUIET ON" : "UNREAD"; technical: true; color: Design.accent }
            FText {
                text: Sky.unreadLine(root.items)
                headline: true
                font.pixelSize: Design.readout
                font.weight: Font.Bold
                font.capitalization: Font.MixedCase
            }
        }
        Item { Layout.fillWidth: true }
        FButton {
            Layout.alignment: Qt.AlignTop
            label: root.inbox.dnd ? "Quiet on" : "Quiet off"
            symbol: root.inbox.dnd ? "notifications_off" : "notifications"
            selected: root.inbox.dnd
            onClicked: root.inbox.setDnd(!root.inbox.dnd)
        }
        FButton {
            Layout.alignment: Qt.AlignTop
            label: "Mark read"
            symbol: "done_all"
            onClicked: root.inbox.markAllRead()
        }
    }

    // The sky: hours, the horizon, NOW, the comets.
    Item {
        id: skyArea
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: 140
        readonly property real inset: 22
        readonly property real span: width - 2 * inset
        Repeater {
            model: Sky.hours(root.sky)
            Item {
                required property var modelData
                x: skyArea.inset + skyArea.span * modelData.at
                height: skyArea.height
                Rectangle { width: 1; height: parent.height; color: Qt.alpha(Design.line, 0.35) }
                FText {
                    anchors.horizontalCenter: parent.left
                    anchors.top: parent.bottom
                    anchors.topMargin: 4
                    text: String(modelData.hour).padStart(2, "0") + ":00"
                    technical: true
                    color: Design.faint
                }
            }
        }
        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Design.line }
        FText { y: 4; text: "URGENT"; technical: true; color: Design.faint }
        FText { anchors.bottom: parent.bottom; anchors.bottomMargin: 6; text: "QUIET"; technical: true; color: Design.faint }
        Rectangle { x: skyArea.inset + skyArea.span; width: 2; height: parent.height; color: Design.accent }
        FText {
            anchors.horizontalCenter: parent.right
            anchors.horizontalCenterOffset: -skyArea.inset
            anchors.bottom: parent.top
            text: "NOW"
            technical: true
            color: Design.accent
        }
        Repeater {
            model: root.items
            Item {
                id: slot
                required property var modelData
                required property int index
                x: skyArea.inset + skyArea.span * Sky.along(modelData.time, root.sky)
                y: skyArea.height * Sky.height(modelData.urgency, index)
                z: slot.modelData.id === root.selected?.id ? 2 : 1
                InboxComet {
                    app: slot.modelData.appName || "app"
                    summary: slot.modelData.summary || ""
                    unread: !slot.modelData.read
                    urgent: slot.modelData.urgency === "critical"
                    chosen: slot.modelData.id === root.selected?.id
                    onClicked: root.selectedId = slot.modelData.id
                }
            }
        }
        Column {
            anchors.centerIn: parent
            spacing: 8
            visible: root.items.length === 0
            FText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.inbox.available ? "NO TRANSMISSIONS" : "USE HOST CENTER"
                font.pixelSize: Design.readout
                color: Design.muted
            }
            FText {
                anchors.horizontalCenter: parent.horizontalCenter
                aside: true
                visible: root.mirrored
                text: "Earlier messages and actions are in the host center."
                font.pixelSize: Design.caption
                color: Design.faint
            }
        }
    }

    // The reading panel: the selected notice, readable, then what you can do with it.
    Item {
        id: card
        Layout.fillWidth: true
        Layout.topMargin: 22
        Layout.preferredHeight: cardText.implicitHeight + 28
        visible: !!root.selected
        Plane { id: plane; anchors.fill: parent; role: "ink"; backing: true; slant: 3 }
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 36
            anchors.rightMargin: 36
            spacing: 16
            ColumnLayout {
                id: cardText
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 6
                RowLayout {
                    Layout.fillWidth: true
                    FText {
                        Layout.fillWidth: true
                        text: (root.selected?.appName ?? "") + " · " + root.timestamp(root.selected?.time ?? 0)
                        technical: true
                        color: plane.textColor
                    }
                    FText {
                        visible: root.selected?.urgency === "critical"
                        text: "URGENT"
                        technical: true
                        color: Design.danger
                    }
                }
                FText {
                    Layout.fillWidth: true
                    text: root.selected?.summary ?? ""
                    headline: true
                    sheared: true
                    font.pixelSize: Design.figure
                    font.weight: Font.Black
                    font.capitalization: Font.MixedCase
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    color: plane.textColor
                }
                FText {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: (root.selected?.body ?? "").replace(/<[^>]*>/g, "").slice(0, 2000)
                    wrapMode: Text.Wrap
                    maximumLineCount: 3
                    elide: Text.ElideRight
                    font.pixelSize: Design.body
                    font.capitalization: Font.MixedCase
                    color: plane.textColor
                }
            }
            Image {
                id: picture
                visible: status === Image.Ready
                Layout.preferredWidth: root.pictureSide
                Layout.preferredHeight: root.pictureSide
                Layout.alignment: Qt.AlignVCenter
                source: root.selected?.image ?? ""
                sourceSize.width: root.pictureSide
                sourceSize.height: root.pictureSide
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                onStatusChanged: if (status === Image.Ready && root.selected) root.inbox.keepImage(root.selected.id, picture)
            }
        }
    }
    RowLayout {
        Layout.fillWidth: true
        visible: !!root.selected
        spacing: 10
        InboxAnswer {
            Layout.fillWidth: true
            item: root.selected ?? ({})
            inbox: root.inbox
            onOpenHost: root.shell.openHost("notifications")
        }
        FButton {
            Layout.alignment: Qt.AlignTop
            symbol: "close"
            label: "Dismiss"
            hint: "Dismiss notification"
            onClicked: root.inbox.dismiss(root.selected.id)
        }
    }

    // The attention band: sources, arrivals and the silence's debt (AttentionBand; atlas #33–35).
    AttentionBand {
        Layout.fillWidth: true
        items: root.inbox.items
        active: root.visible && root.shell.panelOpen
    }
    RowLayout {
        FText {
            text: root.inbox.items.length + " RECEIVED · " + root.unread + " UNREAD · CLICK A COMET TO READ IT"
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
