import QtQuick
import Quickshell
import Quickshell.Services.Notifications

// Our notification server (Z166): Quickshell's, behind the notification bus name. It holds the live notifications
// and says what arrives, changes and closes; the Inbox in the core is the list (adapters/dms/DmsNotifications.qml
// joins the two). While another program holds the name Quickshell waits and takes it when that one leaves.
// The arrival rules are from DMS's Services/NotificationService.qml (MIT, see NOTICE).
Scope {
    id: root
    property bool enabled: false
    // Do-not-disturb: a transient notification that may not show has nowhere to go, so it is turned away.
    property bool quiet: false
    // Ids are unique across restarts of this process: Quickshell's own start again from 1.
    readonly property string session: Date.now().toString(36)
    property var live: ({})   // key → QuickshellNotification
    readonly property var keys: Object.keys(live)
    signal arrived(QuickshellNotification item)
    signal changed(QuickshellNotification item)
    signal closed(string key)

    // A flood guard: past this many in one second, only critical ones are taken.
    readonly property int maxPerSecond: 20
    property real windowStart: 0
    property int inWindow: 0
    function admitted(critical: bool): bool {
        const now = Date.now();
        if (now - windowStart >= 1000) { windowStart = now; inWindow = 0; }
        inWindow += 1;
        return critical || inWindow <= maxPerSecond;
    }

    function find(key: string): QuickshellNotification { return live[key] ?? null; }
    function invoke(key: string, action: string): bool { return find(key)?.invoke(action) ?? false; }
    function reply(key: string, text: string): bool { return find(key)?.reply(text) ?? false; }
    function dismiss(key: string): void { find(key)?.dismiss(); }

    function forget(item: QuickshellNotification): void {
        const rest = Object.assign({}, live);
        delete rest[item.key];
        live = rest;
        closed(item.key);
        item.destroy();
    }

    Component {
        id: liveNotification
        QuickshellNotification {
            id: item
            onChanged: root.changed(item)
            onClosed: root.forget(item)
        }
    }

    LazyLoader {
        active: root.enabled
        NotificationServer {
            keepOnReload: false
            bodySupported: true
            bodyMarkupSupported: false
            actionsSupported: true
            imageSupported: true
            inlineReplySupported: true
            persistenceSupported: true
            onNotification: notification => {
                const critical = notification.urgency === NotificationUrgency.Critical;
                if (!root.admitted(critical) || (notification.transient && root.quiet && !critical)) {
                    notification.dismiss();
                    return;
                }
                notification.tracked = true;
                const item = liveNotification.createObject(root, { notification: notification, key: root.session + "-" + notification.id });
                root.live = Object.assign({}, root.live, { [item.key]: item });
                root.arrived(item);
            }
        }
    }
}
