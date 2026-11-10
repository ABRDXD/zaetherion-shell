// Notification: { id, appName, summary, body, time, urgency, read, hasActions }; newest last.
// available = the mirror is listening.
HostDomain {
    property var items: []
    property int unread: 0
    property bool dnd: false

    function setDnd(on: bool) { record("setDnd", [on]); }
    function markAllRead() { record("markAllRead", []); }
    function dismiss(id: string) { record("dismiss", [id]); }
    function openHost() { record("openHost", []); }
}
