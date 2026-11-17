import qs.view.ui
import QtQuick

// How one Inbox item is answered: a button per action and a reply field while the notification is live at our own
// server (S4); a way to the host's centre while the item is only mirrored from the host's server.
Flow {
    id: root
    required property var item      // a contract notification
    required property var inbox     // NotificationsDomain
    signal openHost()
    readonly property bool live: item.live === true
    readonly property var actions: live ? item.actions ?? [] : []
    readonly property bool replies: live && !!item.reply
    readonly property bool hostOnly: !live && inbox.source === "mirror" && !!item.hasActions
    readonly property int replyWidth: 280
    visible: actions.length > 0 || replies || hostOnly
    spacing: 6

    function send(): void {
        if (reply.text.trim() === "") return;
        inbox.invoke(item.id, "", reply.text);
        reply.text = "";
    }

    Repeater {
        model: root.actions
        FButton {
            required property var modelData
            label: String(modelData.label ?? "").trim() || "Open"  // a blank label (" ") is no label
            onClicked: root.inbox.invoke(root.item.id, modelData.id, "")
        }
    }
    FField {
        id: reply
        visible: root.replies
        implicitWidth: root.replyWidth
        placeholderText: root.item.reply ?? ""
        Accessible.name: "Reply"
        onAccepted: root.send()
    }
    FButton {
        visible: root.replies
        symbol: "send"
        hint: "Send reply"
        enabled: reply.text.trim() !== ""
        onClicked: root.send()
    }
    FButton {
        visible: root.hostOnly
        label: "Actions in host center"
        onClicked: root.openHost()
    }
}
