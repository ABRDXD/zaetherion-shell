import QtQuick
import Quickshell.Services.Notifications

// One live notification held by QuickshellNotificationServer: its id in our Inbox, its fields as the core takes
// them (`notif.ingest`), and the calls only a live notification can answer. Adapted from NotifWrapper in DMS's
// Services/NotificationService.qml (MIT, see NOTICE).
QtObject {
    id: root
    required property Notification notification
    required property string key
    readonly property string urgency: NotificationTiming.urgencies[notification.urgency] ?? "normal"
    readonly property int showMs: NotificationTiming.showMs(notification.expireTimeout, urgency)
    // Quickshell gives a file or a themed icon as image://icon/<path or name>, and raw pixels as image://qsimage/….
    readonly property string iconPrefix: "image://icon/"
    readonly property string image: notification.image ?? ""
    readonly property string imageFile: image.startsWith(iconPrefix + "/") ? image.slice(iconPrefix.length)
                                      : image.startsWith("file://") ? image.slice("file://".length) : image.startsWith("/") ? image : ""
    readonly property string imageIcon: image.startsWith(iconPrefix) && !imageFile ? image.slice(iconPrefix.length) : ""
    // Pixels that exist only in this process, until they are saved (NotificationsDomain.keepImage).
    readonly property string livePicture: image !== "" && !imageFile && !imageIcon ? image : ""
    readonly property var fields: ({
        id: key, appName: notification.appName, summary: plain(notification.summary), body: plain(notification.body),
        urgency: urgency, actions: notification.actions.map(a => ({ id: a.identifier, label: a.text })),
        reply: notification.hasInlineReply ? (notification.inlineReplyPlaceholder || "Reply") : "",
        icon: notification.appIcon || imageIcon || notification.desktopEntry, image: imageFile,
        timeout: showMs, transient: notification.transient, silent: !!notification.hints["suppress-sound"]
    })
    signal changed()   // a replace-id rewrote the fields
    signal closed()

    onFieldsChanged: changeLater.restart()
    // A replace changes several properties in a row: report them once.
    readonly property Timer changeLater: Timer { interval: 0; onTriggered: root.changed() }

    // A transient notification is not kept: it leaves when its showing time ends.
    readonly property Timer transientEnd: Timer {
        interval: root.showMs
        running: root.notification.transient && root.showMs > 0
        onTriggered: root.notification.expire()
    }
    readonly property Connections link: Connections {
        target: root.notification
        function onClosed() { root.closed(); }
    }

    // Bodies may carry markup; our cards draw plain text.
    function plain(text: string): string { return text.replace(/<[^>]*>/g, "").trim(); }

    function invoke(action: string): bool {
        const found = notification.actions.find(a => a.identifier === action);
        if (found) found.invoke();
        return found !== undefined;
    }
    function reply(text: string): bool {
        if (!notification.hasInlineReply || text === "") return false;
        notification.sendInlineReply(text);
        return true;
    }
    function dismiss(): void { notification.dismiss(); }
}
