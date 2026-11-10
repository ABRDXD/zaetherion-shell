import qs.view.contract
import qs.view.ui
import QtQuick

// Notifications as a planet: the unread count (the alarm while any are unread) and how many the
// mirror holds; never an app, a summary or a body (privacy). Do-not-disturb is said in the note.
// No lease: the mirror already holds the counts.
Face {
    id: root
    required property HostAdapter host
    readonly property var notifications: host.notifications
    readonly property int held: notifications.items.length
    readonly property int unread: notifications.unread

    figure: notifications.available ? String(unread) : "–"
    brief: !notifications.available ? "–" : notifications.dnd ? "QUIET" : unread > 0 ? unread + " NEW" : "READ"
    note: !notifications.available ? "NOT LISTENING" : notifications.dnd ? "QUIET" : unread > 0 ? "UNREAD" : "ALL READ"
    detail: notifications.available ? held + " HELD" + (notifications.dnd ? " · DO NOT DISTURB" : "") : ""
    alarm: notifications.available && unread > 0 && !notifications.dnd

    Accessible.role: Accessible.StaticText
    Accessible.name: notifications.available ? unread + " unread notifications" : "Notifications not listening"
}
