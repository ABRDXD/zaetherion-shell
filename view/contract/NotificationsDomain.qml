import QtQuick

// Notification: { id, appName, summary, body, time, urgency ("low"|"normal"|"critical"), read, hasActions,
// actions [{id, label}], reply (the reply field's placeholder, "" = none), icon, image, timeout (showing time in
// ms, 0 = until dismissed, negative = the reader's own default), live }; newest last.
// available = something is listening. source = "server" when our own notification server holds the items (their
// actions and replies can be answered here while `live`), "mirror" when they are read from the host's.
HostDomain {
    property var items: []
    property int unread: 0
    property bool dnd: false
    property string source: "mirror"

    function setDnd(on: bool) { record("setDnd", [on]); }
    function markAllRead() { record("markAllRead", []); }
    function dismiss(id: string) { record("dismiss", [id]); }
    // Answer a live notification: its action, or (reply not empty) its inline reply.
    function invoke(id: string, action: string, reply: string) { record("action", [id, action, reply]); }
    // `picture` is that notification's image as now drawn. An adapter whose pictures exist only in this process
    // saves it, so the item still has one after a restart; it is kept at the size it was shown.
    function keepImage(id: string, picture: Item) { record("keepImage", [id]); }
    function openHost() { record("openHost", []); }
}
