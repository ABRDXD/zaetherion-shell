// ClipEntry: { id, text, isImage }; text is the history preview line. Lease "history".
HostDomain {
    property var entries: []
    // The history has been read at least once since "history" was leased (an empty list is then really empty).
    property bool loaded: false
    // Decoded image clips, id -> image URL; filled by requestThumbnail, dropped with the lease (Z79: visible rows only).
    property var thumbnails: ({})

    signal textFetched(string id, string text)

    function refresh() { record("refresh", []); }
    function copy(id: string) { record("copy", [id]); }
    // Copies the entry, then sends the paste keystroke to the window that has the keyboard once the caller has let go.
    function paste(id: string) { record("paste", [id]); }
    function remove(id: string) { record("remove", [id]); }
    function copyText(text: string) { record("copyText", [text]); }
    function fetchText(id: string) { record("fetchText", [id]); }
    function requestThumbnail(id: string) { record("requestThumbnail", [id]); }
}
