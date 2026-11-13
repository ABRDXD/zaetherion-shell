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
    function openHost() { record("openHost", []); }
}
